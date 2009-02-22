package org.ffilmation.engine.renderEngines.flash9RenderEngine {
	
		// Imports
	  import flash.display.*
	  import flash.events.*	
	  import flash.filters.*	
		import flash.geom.*
		import flash.utils.*
		import flash.filters.DisplacementMapFilter
		import flash.filters.DisplacementMapFilterMode

		import org.ffilmation.utils.*
		import org.ffilmation.utils.polygons.*
		import org.ffilmation.engine.core.*
		import org.ffilmation.engine.events.*
		import org.ffilmation.engine.elements.*
		import org.ffilmation.engine.renderEngines.flash9RenderEngine.helpers.*
	  
		/**
		* This class renders fPlanes
		* @private
		*/
		public class fFlash9PlaneRenderer extends fFlash9ElementRenderer {
		
			// Private properties
			private var origWidth:Number
			private var origHeight:Number
			private var	cacheTimer:Timer

			public var scrollR:Rectangle							 // Scroll Rectangle for this plane, to optimize viewing areas.
			public var planeDeform:Matrix						   // Transformation matrix for this plane that sets the proper perspective
			public var clipPolygon:fPolygon						 // This is the shape polygon with perspective applied

			// Cache for this plane, to bake a bitmap of it when it doesn't change
			public var finalBitmap:Bitmap
			private var finalBitmapData:BitmapData

			// Light related data structures
			protected var lightC:Sprite								 // All lights
			private var environmentC:Shape				     // Global
			private var black:Shape				  				   // No light
			private var diffuseData:BitmapData			 	 // Diffuse map
			private var diffuse:Bitmap					 	 		 // Diffuse map
			private var simpleHolesC:Sprite				    

			private var spriteToDraw:Sprite
			public var baseContainer:DisplayObjectContainer
			private var behind:DisplayObjectContainer  // Elements behind the wall will added here
			private var infront:DisplayObjectContainer // Elements in front of the wall will added here
			
			private var bumpMap:BumpMap								 // Bump maps
			private var bumpMapData:BitmapData
			private var displacer:DisplacementMapFilter
			private var tMatrix:Matrix
			private var tMatrixB:Matrix
			private var firstBump:Boolean = true
			
			private var anyClosedHole:Boolean
			private var canBeSmoothed:Boolean

			public var deformedSimpleShadowsLayer:Sprite
			public var simpleShadowsLayer:Sprite		   // Simple shadows go here
			public var lightClips:Array                // List of containers used to represent lights (interior)
			public var lightMasks:Array                // List of containers representing the light mask / shape
			public var lightShadowsPl:Array            // Containers where geometry shadows are drawn
			public var lightShadowsObj:Array           // Containers where geometry shadows are drawn
			public var lightBumps:Array           	   // Bump map layers
			public var zIndex:Number = 0						   // zIndex
			public var lightStatuses:Array      			 // References to light status
			
			// Occlusion related
			private var occlusionCount:Number = 0
			private var occlusionLayer:Sprite
			private var occlusionSpots:Object

			// Constructor
			function fFlash9PlaneRenderer(rEngine:fFlash9RenderEngine,element:fPlane,width:Number,height:Number,spriteToDraw:Sprite,spriteToShowHide:fElementContainer):void {
				
 			   // This is the polygon that is drawn to represent this plane, with perspective applied
				 this.clipPolygon = new fPolygon()
				 var contours:Array = element.shapePolygon.contours

				 // Process shape vertexes
				 if(element is fFloor) {
				 		
				 		for(var k:int=0;k<contours.length;k++) {
				 			var c:Array = contours[k]
				 			var projectedShape:Array = new Array
				 			for(var k2:int=0;k2<c.length;k2++) 	projectedShape[k2] = fScene.translateCoords(c[k2].x,c[k2].y,0)
				 			this.clipPolygon.contours[this.clipPolygon.contours.length] = projectedShape
				 		}
				 		
				 } else if(element is fWall) {

 				 		var w:fWall = element as fWall
				 	  if(w.vertical) {
				 			for(k=0;k<contours.length;k++) {
				 				c = contours[k]
				 				projectedShape = new Array
				 				for(k2=0;k2<c.length;k2++) projectedShape[k2] = fScene.translateCoords(0,c[k2].x,c[k2].y)
				 				this.clipPolygon.contours[this.clipPolygon.contours.length] = projectedShape
				 			}
				 	  } else {
				 			for(k=0;k<contours.length;k++) {
				 				c = contours[k]
				 				projectedShape = new Array
				 				for(k2=0;k2<c.length;k2++) projectedShape[k2] = fScene.translateCoords(c[k2].x,0,c[k2].y)
				 				this.clipPolygon.contours[this.clipPolygon.contours.length] = projectedShape
				 			}
				 	  }
				 }

 			   // Retrieve diffuse map
 			   var d:DisplayObject = element.material.getDiffuse(element,width,height,true)
 			   this.diffuseData = new BitmapData(element.bounds2d.width,element.bounds2d.height,true,0)
				 var oMatrix:Matrix = this.planeDeform.clone()
				 oMatrix.translate(0,-Math.round(element.bounds2d.y))
				 this.diffuseData.draw(d,oMatrix)
 			   this.diffuse = new Bitmap(this.diffuseData,"never",true)
 			   this.diffuse.y = Math.round(element.bounds2d.y)

				 // Previous
				 super(rEngine,element,null,spriteToShowHide)

				 // Properties
			   this.origWidth = d.width
			   this.origHeight = d.height
			   this.spriteToDraw = spriteToDraw

				 // This is the Sprite where all light layers are generated.
				 // This Sprite is attached to the sprite that is visible onscreen
				 this.baseContainer = objectPool.getInstanceOf(Sprite) as Sprite
				 this.behind = objectPool.getInstanceOf(Sprite) as Sprite
				 this.infront = objectPool.getInstanceOf(Sprite) as Sprite
			   this.behind.cacheAsBitmap = true
			   this.infront.cacheAsBitmap = true
			   
			   this.baseContainer.addChild(this.behind)
			   this.baseContainer.addChild(this.diffuse)
			   this.baseContainer.addChild(this.infront)
			   
			   this.finalBitmap = new Bitmap(null,"never",true)

			   // LIGHT
			   this.lightClips = new Array  
			   this.lightStatuses = new Array   		
			   this.lightMasks = new Array   		
			   this.lightShadowsObj = new Array   		
			   this.lightShadowsPl = new Array   		
			   this.lightBumps = new Array   		
			   this.lightC = objectPool.getInstanceOf(Sprite) as Sprite
			   this.simpleHolesC = objectPool.getInstanceOf(Sprite) as Sprite
				 this.black = new Shape()
			   this.environmentC = new Shape()
 			   this.lightC.mouseEnabled = false
 			   this.lightC.mouseChildren = false

			   this.baseContainer.addChild(this.lightC)
			   this.lightC.addChild(this.black)
			   this.lightC.addChild(this.environmentC)
			   this.lightC.blendMode = BlendMode.MULTIPLY
 			   this.lightC.mouseEnabled = false
 			   this.lightC.mouseChildren = false
				 this.baseContainer.mouseEnabled = false

				 // Object shadows with qualities other than fShadowQuality.BEST will be drawn here instead of into each lights's ERASE layer
				 this.deformedSimpleShadowsLayer = objectPool.getInstanceOf(Sprite) as Sprite
				 this.deformedSimpleShadowsLayer.mouseEnabled = false
				 this.deformedSimpleShadowsLayer.mouseChildren = false
				 this.deformedSimpleShadowsLayer.transform.matrix = this.planeDeform
				 this.simpleShadowsLayer = objectPool.getInstanceOf(Sprite) as Sprite
				 this.simpleShadowsLayer.scrollRect = this.scrollR
				 this.spriteToDraw.addChild(this.deformedSimpleShadowsLayer)
				 this.deformedSimpleShadowsLayer.addChild(this.simpleShadowsLayer)

				 // Occlusion
				 this.occlusionLayer = objectPool.getInstanceOf(Sprite) as Sprite
				 this.occlusionLayer.mouseEnabled = false
			   this.occlusionLayer.blendMode = BlendMode.ERASE
				 this.occlusionLayer.transform.matrix = this.planeDeform
				 this.occlusionLayer.scrollRect = this.scrollR
				 this.occlusionSpots = new Object
				 if(element is fWall) {
				 		w = element as fWall
				 		this.simpleShadowsLayer.y-=w.pixelHeight
				 		this.occlusionLayer.y-=w.pixelHeight*fEngine.DEFORMATION
				 }

				 // Holes
			   this.processHoles(element)
				 this.canBeSmoothed = (element.shapePolygon.contours.length==1 && element.holes.length==0)
			   
			   // Cache as Bitmap with Timer cache
			   // The cache is disabled while the Plane is being modified and a timer is set to re-enable it
			   // if the plane doesn't change in a while
         this.undoCache()
				 this.cacheTimer = new Timer(100,1)
         this.cacheTimer.addEventListener(TimerEvent.TIMER, this.cacheTimerListener,false,0,true)
         this.cacheTimer.start()
         
         // Listen to changes in material
         element.addEventListener(fPlane.NEWMATERIAL,this.newMaterial,false,0,true)

			}
			
			// PLANE CACHE
			//////////////
			
			/**
			* Cache on
			*/
			public function doCache():void {
				
				 // Already cached
				 if(this.finalBitmap.parent || this.anyClosedHole) return
				 
				 // Soft shadows on
				 if(fEngine.softShadows>0 && this.canBeSmoothed) {
				 		var blur:BlurFilter = new BlurFilter(fEngine.softShadows,fEngine.softShadows)
				 		for(var i:int=0;i<this.lightShadowsPl.length;i++) {
								if(this.lightShadowsPl[i]) this.lightShadowsPl[i].filters = [blur]
				 		}
				 }
				 
				 // New cache
				 if(this.finalBitmapData) this.finalBitmapData.dispose()
			   this.finalBitmapData = new BitmapData(this.element.bounds2d.width,this.element.bounds2d.height,true,0)
				 
				 // Draw
				 var oMatrix:Matrix = new Matrix()
				 oMatrix.translate(0,-this.diffuse.y)
				 this.finalBitmapData.draw(this.baseContainer, oMatrix )
				 
				 // Display
				 this.finalBitmap.bitmapData = this.finalBitmapData
				 this.finalBitmap.y = this.diffuse.y
			   this.spriteToDraw.addChildAt(this.finalBitmap,0)
			   
			   try { this.spriteToDraw.removeChild(this.baseContainer) } catch(e:Error) {}

         this.container.cacheAsBitmap = true

			}
			
			/**
			* Cache off
			*/
			public function undoCache(autoStart:Boolean = false):void {
		   		
		   	 if(!this.diffuse) return

				 // Soft shadows off
				 for(var i:int=0;i<this.lightShadowsPl.length;i++) {
						if(this.lightShadowsPl[i]) this.lightShadowsPl[i].filters = []
				 }

		   	 var p:fPlane = this.element as fPlane
				 if(this.finalBitmapData) this.finalBitmapData.dispose()
			   this.spriteToDraw.addChildAt(this.baseContainer,0)
			   try { this.spriteToDraw.removeChild(this.finalBitmap) } catch(e:Error) {}
         		
         this.container.cacheAsBitmap = false

         if(autoStart) this.cacheTimer.start()
         
			}

			/**
			* This listener sets the cache of a Plane back to true when it doesn't change for a while
			*/
			public function cacheTimerListener(event:TimerEvent):void {
       	 this.doCache()
			}

			// REACT TO CHANGES IN SCENE
			////////////////////////////


			/** 
			* Sets global light
			*/
			public override function renderGlobalLight(light:fGlobalLight):void {
				
				 this.black.graphics.clear()
				 this.black.graphics.beginFill(0x000000,1)
				 this.clipPolygon.draw(this.black.graphics)
				 this.black.graphics.endFill()

				 this.environmentC.graphics.clear()
				 this.environmentC.graphics.beginFill(light.hexcolor,1)
				 this.clipPolygon.draw(this.environmentC.graphics)
				 this.environmentC.graphics.endFill()

				 // Environment
				 this.environmentC.alpha = light.intensity/100
				 this.simpleShadowsLayer.alpha = 1-this.environmentC.alpha

			}
	
			/** 
			* Listens for changes in global light intensity
			*/
			public override function processGlobalIntensityChange(light:fGlobalLight):void {
				
					 this.environmentC.alpha = light.intensity/100
					 this.simpleShadowsLayer.alpha = 1-this.environmentC.alpha
					 this.undoCache(true)
			}

			/**
			* Global light changes color
			*/
			public override function processGlobalColorChange(light:fGlobalLight):void {
					 this.renderGlobalLight(light)
					 this.undoCache(true)
			}

			/**
			* Listens to changes of a light's intensity
			*/
			private function processLightIntensityChange(event:Event):void {
				  var light:fLight = event.target as fLight
					this.redrawLight(light)
					this.undoCache(true)
			}

			/**
			* This listens to the plane receiving a new material
			*/
			private function newMaterial(evt:fNewMaterialEvent):void {
			
			 	 // Diffuse
			 	 var p:fPlane = evt.target as fPlane
			 	 var nDiffuse = p.material.getDiffuse(element,evt.width,evt.height,true)
 			   var d:Sprite = nDiffuse as Sprite
 			   d.mouseEnabled = false
 			   d.mouseChildren = false
 			   this.baseContainer.addChild(nDiffuse)
 			   this.baseContainer.swapChildren(this.diffuse,nDiffuse)
 			   this.baseContainer.removeChild(this.diffuse)
 			   
 			   //this.diffuse = this.containerToPaint = nDiffuse
 			   
 			   // Holes
	   		 this.processHoles(p)
	   		 
	   		 // Redraw lights
	   		 if(this.scene.IAmBeingRendered) {
	   		 	this.redrawLights()
	   		 	this.undoCache(true)
	   		 }
			
			}

			/** 
			*	Shows light
			*/
			private function showLight(light:fLight):void {
			
			   var lClip:Sprite = this.lightClips[light.uniqueId]
			   this.lightC.addChild(lClip)
				
			}
			
			/** 
			*	Hides light
			*/
			private function hideLight(light:fLight):void {
			
			   var lClip:Sprite = this.lightClips[light.uniqueId]
			   this.lightC.removeChild(lClip)
			
			}
			

			// HOLE MANAGEMENT
			//////////////////


			/**
			* This processes new hole definitions for this plane
			*/
			private function processHoles(element:fPlane):void {
				
			   this.deformedSimpleShadowsLayer.blendMode = BlendMode.NORMAL
			   this.simpleHolesC.blendMode = BlendMode.NORMAL
			   try {
			   		this.deformedSimpleShadowsLayer.removeChild(this.simpleHolesC)
	   		 } catch(e:Error) {}

			   this.anyClosedHole = false
			   for(var i:Number=0;i<element.holes.length;i++) {
			   		var hole:fHole = element.holes[i]
   					 hole.addEventListener(fHole.OPEN,this.openHole,false,0,true)
				 		 hole.addEventListener(fHole.CLOSE,this.closeHole,false,0,true)
				 		 if(hole.block) {

		 		 				hole.block.transform.matrix = this.planeDeform
				 		 		if(!hole.open) {
			 		 				this.behind.addChild(hole.block)
		   						this.anyClosedHole = true
				 		 		}

				 		 	 	if(element is fFloor) {
				 		 	 		var p:Point =	fScene.translateCoords(hole.bounds.xrel,hole.bounds.yrel,0)
				 		 		}
								else if(this.element is fWall) {
			 	  				if((this.element as fWall).vertical) {
										p =	fScene.translateCoords(0,hole.bounds.xrel,this.origHeight-hole.bounds.yrel)
			 	  				} else {
										p =	fScene.translateCoords(hole.bounds.xrel,0,this.origHeight-hole.bounds.yrel)
									}
								}
				 		 		hole.block.x = p.x
				 		 		hole.block.y = p.y
				 		 }
			   }
				 this.redrawHoles()
				 
			   if(element.holes.length>0) {
			   		this.deformedSimpleShadowsLayer.addChild(this.simpleHolesC)
			   		//this.deformedSimpleShadowsLayer.blendMode = BlendMode.LAYER
			   		this.simpleHolesC.blendMode = BlendMode.ERASE
				 		this.simpleHolesC.mouseEnabled = false
				 		
				 } 


			}

			/**
			* This method listens to holes being opened
			*/
			private function openHole(event:Event):void {
				
				try {
					var hole:fHole = event.target as fHole
					if(hole.block) {
						this.behind.removeChild(hole.block)
				 		this.anyClosedHole = false
					  var p:fPlane = this.element as fPlane
			   		for(var i:Number=0;i<p.holes.length;i++) {
				 				 if(!p.holes[i].open && p.holes[i].block) {
			   						this.anyClosedHole = true
				 				 }
			   		}						
						if(this.scene.IAmBeingRendered) this.redrawLights()
					}
				} catch(e:Error) {
					
				}

			}

			/**
			* This method listens to holes beign closed
			*/
			private function closeHole(event:Event):void {
				
				try {
					var hole:fHole = event.target as fHole
					if(hole.block) {
						this.behind.addChild(hole.block)
					  var p:fPlane = this.element as fPlane
			   		for(var i:Number=0;i<p.holes.length;i++) {
				 				 if(!p.holes[i].open && p.holes[i].block) {
			   						this.anyClosedHole = true
				 				 }
			   		}						
						if(this.scene.IAmBeingRendered) this.redrawLights()
					}
				} catch(e:Error) {
					
				}

			}

			/**
			* Redraws all lights when a hole has been opened/closed
			*/
			private function redrawLights():void {
				  
					this.redrawHoles()
					this.renderGlobalLight(this.element.scene.environmentLight)
					for(var i:Number=0;i<this.element.scene.lights.length;i++) {
						var l:fLight = this.element.scene.lights[i]
						if(l) l.render()
					}
			}

			/**
			* Draws holes into material
			*/
			private function redrawHoles():void {
				
 				 var holes:Array = (this.element as fPlane).holes
				 
				 // Update holes in clipping polygon
				 this.clipPolygon.holes = new Array
				 
 				 for(var h:int=0;h<holes.length;h++) {

					 	if(holes[h].open) {
					 		var hole:fPlaneBounds = holes[h].bounds
						 	var k:int = this.clipPolygon.holes.length
						 	this.clipPolygon.holes[k] = new Array
						 	var tempA:Array = this.clipPolygon.holes[k]
							
				 	  	if(this.element is fFloor) {
				 	  		var p:Point =	fScene.translateCoords(hole.xrel,hole.yrel,0)
				 	  	 	tempA.unshift(p)
				 	  		p =	fScene.translateCoords(hole.xrel+hole.width,hole.yrel,0)
				 	  	 	tempA.unshift(p)
			 	  			p =	fScene.translateCoords(hole.xrel+hole.width,hole.yrel+hole.height,0)
				 	  	 	tempA.unshift(p)
			 	  			p =	fScene.translateCoords(hole.xrel,hole.yrel+hole.height,0)
				 	  	 	tempA.unshift(p)
			 	  			p =	fScene.translateCoords(hole.xrel,hole.yrel,0)
				 	  	 	tempA.unshift(p)
			 	  		}
				 	  	if(this.element is fWall) {
			 	  			if((this.element as fWall).vertical) {
									p =	fScene.translateCoords(0,hole.xrel,this.origHeight-hole.yrel)
				 	  	 		tempA.unshift(p)
				 	  			p =	fScene.translateCoords(0,hole.xrel+hole.width,this.origHeight-hole.yrel)
				 	  	 		tempA.unshift(p)
			 	  				p =	fScene.translateCoords(0,hole.xrel+hole.width,this.origHeight-hole.yrel-hole.height)
				 	  	 		tempA.unshift(p)
			 	  				p =	fScene.translateCoords(0,hole.xrel,this.origHeight-hole.yrel-hole.height)
				 	  	 		tempA.unshift(p)
			 	  				p =	fScene.translateCoords(0,hole.xrel,this.origHeight-hole.yrel)
				 	  	 		tempA.unshift(p)			 	  				
			 	  			} else {
									p =	fScene.translateCoords(hole.xrel,0,this.origHeight-hole.yrel)
				 	  	 		tempA.unshift(p)
				 	  			p =	fScene.translateCoords(hole.xrel+hole.width,0,this.origHeight-hole.yrel)
				 	  	 		tempA.unshift(p)
			 	  				p =	fScene.translateCoords(hole.xrel+hole.width,0,this.origHeight-hole.yrel-hole.height)
				 	  	 		tempA.unshift(p)
			 	  				p =	fScene.translateCoords(hole.xrel,0,this.origHeight-hole.yrel-hole.height)
				 	  	 		tempA.unshift(p)
			 	  				p =	fScene.translateCoords(hole.xrel,0,this.origHeight-hole.yrel)
				 	  	 		tempA.unshift(p)			 	  				
			 	  			}
			 	  		}
			 	  		
			 	  	}
	       }

				 // Erases holes from simple shadows layers
				 this.simpleHolesC.graphics.clear()
 				 for(h=0;h<holes.length;h++) {

					 	if(holes[h].open) {
						 	hole = holes[h].bounds
							this.simpleHolesC.graphics.beginFill(0x000000,1)
				 	  	this.simpleHolesC.graphics.moveTo(hole.xrel,hole.yrel-this.origHeight)
				 	  	this.simpleHolesC.graphics.lineTo(hole.xrel+hole.width,hole.yrel-this.origHeight)
			 	  		this.simpleHolesC.graphics.lineTo(hole.xrel+hole.width,hole.yrel+hole.height-this.origHeight)
			 	  		this.simpleHolesC.graphics.lineTo(hole.xrel,hole.yrel+hole.height-this.origHeight)
			 	  		this.simpleHolesC.graphics.lineTo(hole.xrel,hole.yrel-this.origHeight)
			 	  		this.simpleHolesC.graphics.endFill()
			 	  	}
	       }


			}	

			// LIGHT RENDER CYCLE
			/////////////////////

			/**
			* Starts render process
			*/
			public override function renderStart(light:fLight):void {
			
			   // Create light ?
			   if(!this.lightStatuses[light.uniqueId]) this.lightStatuses[light.uniqueId] = new fLightStatus(this.element as fPlane,light)
			   var lightStatus:fLightStatus = this.lightStatuses[light.uniqueId]
				
			   if(!lightStatus.created) {
			      lightStatus.created = true
			      this.addOmniLight(lightStatus)
			      this.lightIn(light)
			   }
			   
			   // Disable cache. Once the render is finished, a timeout is set that will
			   // restore cache if the object doesn't change for a few seconds.
       	 this.cacheTimer.stop()
       	 this.undoCache()
       	 //this.lightBumps[light.uniqueId].cacheAsBitmap = true
       	 
       	 this.lightShadowsPl[light.uniqueId].graphics.clear()
			  
			}

			/**
			* Creates masks and containers for a new light, and updates lightStatus
			*/
			public function addOmniLight(lightStatus:fLightStatus):void {
			
			   var light:fLight = lightStatus.light
			   lightStatus.lightZ = -2000
			
			   // Create container
			   var light_c:Sprite = objectPool.getInstanceOf(Sprite) as Sprite
			   this.lightClips[light.uniqueId] = light_c
				 light_c.blendMode = BlendMode.ADD

				 // Create layer
				 var lay:Sprite = objectPool.getInstanceOf(Sprite) as Sprite
				 light_c.addChild(lay)
				 this.lightBumps[light.uniqueId] = lay
				 
				 // Create mask
				 var msk:Shape = new Shape()
				 lay.addChild(msk)
			   this.lightMasks[light.uniqueId] = msk
				 
				 // Create plane shadow container
			   var shd:Sprite = objectPool.getInstanceOf(Sprite) as Sprite
			   lay.addChild(shd)
			   this.lightShadowsPl[light.uniqueId] = shd
				 var element:fPlane = this.element as fPlane
			   if(!this.canBeSmoothed) shd.blendMode = BlendMode.ERASE

				 // Create object shadow container
			   shd = objectPool.getInstanceOf(Sprite) as Sprite
			   lay.addChild(shd)
			   shd.blendMode = BlendMode.ERASE
			   shd.transform.matrix = this.planeDeform

			   var shd2:Sprite = objectPool.getInstanceOf(Sprite) as Sprite
			   this.lightShadowsObj[light.uniqueId] = shd2
				 shd2.scrollRect = this.scrollR
				 shd.addChild(shd2)

				 if(element is fWall) {
				 		var w:fWall = element as fWall
				 		shd2.y-=w.pixelHeight
				 }

			
			}
			
			/**
			* Redraws light to be at a new distante of plane
			*/
			public function setLightDistance(light:fLight,distance:Number,deform:Number=1):void {
			
			   if(light.size!=Infinity) {
						this.lightStatuses[light.uniqueId].localScale =	Math.cos(Math.asin((distance)/light.size))*deform
			   }
			}

			/** 
			* Sets light to be a a new position in the plane
			*/
			public function setLightCoordinates(light:fLight,p:Point):void {
				this.lightStatuses[light.uniqueId].localPos =	p
			}
			
			/** 
			* Redraws a light
			*/
			public function redrawLight(light:fLight):void {

	       var lClip:Shape = this.lightMasks[light.uniqueId]
	       lClip.graphics.clear()

			   // Draw light clip
			   if(light.size!=Infinity) {

					  // Gradient setup
					  var radius:Number = this.lightStatuses[light.uniqueId].localScale*light.size
					  var colors:Array = [light.hexcolor, light.hexcolor]
				    var fillType:String = GradientType.RADIAL
				    var alphas:Array = [light.intensity/100, 0]
			  	  var ratios:Array = [254*light.decay/100, 255]
			   	  var spreadMethod:String = SpreadMethod.PAD
			   	  var interpolationMethod:String = "linearRGB"
			   	  var focalPointRatio:Number = 0
				 	  var localPos:Point = this.lightStatuses[light.uniqueId].localPos
				 	  var matr:Matrix = new Matrix()
  			    matr.createGradientBox(radius<<1, radius<<1, 0 ,-radius, -radius)
  			    matr.concat(this.planeDeform)
  			    matr.translate(localPos.x,localPos.y)
			      lClip.graphics.beginGradientFill(fillType, colors, alphas, ratios, matr, spreadMethod, interpolationMethod, focalPointRatio);
			   	
			   } else {
			  		lClip.graphics.beginFill(light.hexcolor,light.intensity/100)
				 }

				 this.clipPolygon.draw(lClip.graphics)
				 lClip.graphics.endFill()
				 
				 // Update bumpmap
				 if(light.size!=Infinity) {
         
				 	if(fEngine.bumpMapping && light.bump) {
				 		
				 		if(this.firstBump) {
			 	 		   this.iniBump()
			 	 		   this.firstBump = false
				 		}
				 		
/*				 		if(this.bumpMap!=null) {
				 			var r = lClip.getBounds(lClip.stage)
				 			var lw:Number = Math.round(r.width/2)
				 			var lh:Number = Math.round(r.height/2)
				 			
				 			// Snap to pixels so bumpmap doesn't flicker
				 			var pos:Point = new Point(lx,ly)
				 			var f:Point = lClip.parent.localToGlobal(pos)
				 			f.x = Math.round(f.x)
				 			f.y = Math.round(f.y)
				 			pos = lClip.parent.globalToLocal(f)
				 			lClip.x = pos.x
				 			lClip.y = pos.y
             	
				 			// Apply bump map
				 			pos = this.tMatrixB.deltaTransformPoint(pos)
				 			var p:Point = new Point(lw-pos.x,lh-pos.y)
				 			p.x = p.x
				 			p.y = p.y-this.tMatrix.ty
				 			displacer.mapBitmap = this.bumpMap.outputData
				 			displacer.mapPoint = p
				 			lClip.filters = [displacer]
				 		} else {
				 			lClip.filters = null
				 	  }*/
				 	} else {
				 		
				 		lClip.filters = null
				 		
				 	}
				 	
				 }

			}


			/** 
			*	Light reaches element
			*/
			public override function lightIn(light:fLight):void {
			
			   // Show container
				 if(this.lightStatuses && this.lightStatuses[light.uniqueId]) this.showLight(light)
				 
				 // Listen to intensity changes
		 		 light.addEventListener(fLight.INTENSITYCHANGE,this.processLightIntensityChange,false,0,true)
		 		 light.addEventListener(fLight.COLORCHANGE,this.processLightIntensityChange,false,0,true)
		 		 light.addEventListener(fLight.DECAYCHANGE,this.processLightIntensityChange,false,0,true)
			   
			}
			
			/** 
			*	Light leaves element
			*/
			public override function lightOut(light:fLight):void {
			
			   // Hide container
			   if(this.lightStatuses[light.uniqueId]) this.hideLight(light)

				 // Stop listening to intensity changes
		 		 //light.removeEventListener(fLight.INTENSITYCHANGE,this.processLightIntensityChange)
		 		 //light.removeEventListener(fLight.COLORCHANGE,this.processLightIntensityChange)
		 		 //light.removeEventListener(fLight.DECAYCHANGE,this.processLightIntensityChange)
		 		 
		 		 this.undoCache(true)
			   
			}

			/**
			* Renders shadows of other elements upon this fElement
			*/
			public override function renderShadow(light:fLight,other:fRenderableElement):void {
			   
			   var msk:Sprite
			   var lightStatus:fLightStatus = this.lightStatuses[light.uniqueId]
			   
			   if(other is fObject) {
			   	
			   	 if(!(other.customData.flash9Renderer as fFlash9ObjectRenderer).eraseShadows) msk = this.simpleShadowsLayer
			   	 else msk = this.lightShadowsObj[light.uniqueId]
			   	 this.renderObjectShadow(light,other as fObject,msk)
			   	 
			   } else {
				 	 
				 	 var pol:fPolygon = this.renderPlaneShadow(light,other)
				 	 if(pol) {
				 	 	 msk = this.lightShadowsPl[light.uniqueId]
				 		 msk.graphics.beginFill(0,1)
				     pol.draw(msk.graphics)
				     msk.graphics.endFill()
				 	 }
				 	 
			   }

			}

			/**
			* Calculates and projects shadows upon this fElement and return the resulting polygon
			*/
			public function renderPlaneShadow(light:fLight,other:fRenderableElement):fPolygon { 
				return null
			}

			/**
			* Ends render
			*/
			public override function renderFinish(light:fLight):void {
				
				 // Create draw shape
				 this.redrawLight(light)
      	 this.cacheTimer.start()
			}


			// OBJECT SHADOW MANAGEMENT
			///////////////////////////


			/** 
			* Resets shadows. This is called when the fEngine.shadowQuality value is changed
			*/
			public override function resetShadows():void {
				 this.simpleShadowsLayer.graphics.clear()
				 this.resetShadowsInt()
			}
			
			public function resetShadowsInt():void {}

			/**
			* Updates shadow of another elements upon this fElement
			*/
			public override function updateShadow(light:fLight,other:fRenderableElement):void {
			   
			   try {
			    
			   	var msk:Sprite
			   	if(other is fObject && !(other.customData.flash9Renderer as fFlash9ObjectRenderer).eraseShadows) {
			   		msk = this.simpleShadowsLayer
					  this.container.cacheAsBitmap = false
			   	}
			   	else {
			   		msk = this.lightShadowsObj[light.uniqueId]
			    	// Disable cache. Once the render is finished, a timeout is set that will
			    	// restore cache if the object doesn't change for a few seconds.
     	  		this.cacheTimer.stop()
			    	if(this.container.cacheAsBitmap==true) this.undoCache()
       	  	
					  // Start cache timer
					  this.cacheTimer.start()

			   	}
				 			
				 	// Render
				  this.renderObjectShadow(light,other as fObject,msk)
				  
				 } catch(e:Error) { }
				 
				 
			}

			/**
			* Calculates and projects shadows of objects upon this fElement
			*/
			public function renderObjectShadow(light:fLight,other:fObject,msk:Sprite):void {	}	


			// OCCLUSION RENDER MANAGEMENT
			//////////////////////////////


			/**
			* Starts acclusion related to one character
			*/
			public override function startOcclusion(character:fCharacter):void {
				
					if(this.occlusionCount==0) {
						this.container.addChild(this.occlusionLayer)
						this.disableMouseEvents()
					}
					this.occlusionCount++
					
					// Create spot if needed
					if(!this.occlusionSpots[character.uniqueId]) {
						var spr:Sprite = objectPool.getInstanceOf(Sprite) as Sprite
						spr.mouseEnabled = false
						spr.mouseChildren = false
						
						var size:Number = (character.radius>character.height) ? character.radius : character.height
						size *= 1.5
						movieClipUtils.circle(spr.graphics,0,0,size,50,0xFFFFFF,character.occlusion)
						this.occlusionSpots[character.uniqueId] = spr
					}
					
					this.occlusionLayer.addChild(this.occlusionSpots[character.uniqueId])
					
			}

			/**
			* Updates acclusion related to one character
			*/
			public override function updateOcclusion(character:fCharacter):void {
					var spr:Sprite = this.occlusionSpots[character.uniqueId]
					if(!spr) return
					var p:Point = new Point(0,-character.height/2)
					p = character.container.localToGlobal(p)
					p = this.occlusionLayer.globalToLocal(p)
					spr.x = p.x
					spr.y = p.y
			}

			/**
			* Stops acclusion related to one character
			*/
			public override function stopOcclusion(character:fCharacter):void {
					if(!this.occlusionSpots[character.uniqueId]) return
					this.occlusionLayer.removeChild(this.occlusionSpots[character.uniqueId])
					this.occlusionCount--
					if(this.occlusionCount==0) {
						this.enableMouseEvents()
						this.container.removeChild(this.occlusionLayer)
					}
			}


			// OTHER
			////////
			
			/**
			* Mouse management
			*/
			public override function disableMouseEvents():void {
				this.container.mouseEnabled = false
				this.spriteToDraw.mouseEnabled = false
			}

			/**
			* Mouse management
			*/
			public override function enableMouseEvents():void {
				this.container.mouseEnabled = true
				this.spriteToDraw.mouseEnabled = true
			}


			/**
			* Creates bumpmapping for this plane
			*/
			public function iniBump():void {

			   // Bump map ?
	       try {

				 		var ptt:DisplayObject = (this.element as fPlane).material.getBump(this.element,this.container.width,this.container.height,true)
						
						this.bumpMapData = new BitmapData(this.container.width,this.container.height)
						this.tMatrix = this.container.transform.matrix.clone()
//						this.tMatrix.concat(this.spriteToDraw.transform.matrix)
						this.tMatrixB = this.tMatrix.clone()
				 		var bnds = this.container.getBounds(this.container.parent)
						this.tMatrix.ty = Math.round(-bnds.top)
						this.bumpMapData.draw(ptt,this.tMatrix)
						
				 		this.bumpMap = new BumpMap(this.bumpMapData)
				 		this.displacer = new DisplacementMapFilter();
				 		this.displacer.componentX = BumpMap.COMPONENT_X;
				 		this.displacer.componentY = BumpMap.COMPONENT_Y;
				 		this.displacer.mode =	DisplacementMapFilterMode.COLOR
				 		this.displacer.alpha =	0
				 		this.displacer.scaleX = -180;
				 		this.displacer.scaleY = -180;
				 		
//				 		var r:Bitmap = new Bitmap(this.bumpMap.outputData)
//				 		var r:Bitmap = new Bitmap(this.bumpMapData)
//				 		this.container.parent.addChild(r)

				 } catch (e:Error) {
				 		this.bumpMapData = null
				 		this.bumpMap = null
				 		this.displacer = null

				 }
			}

			/** @private */
			public function disposePlaneRenderer():void {

				this.undoCache()
        this.cacheTimer.removeEventListener(TimerEvent.TIMER, this.cacheTimerListener)
       	this.cacheTimer.stop()
       	this.cacheTimer = null
       	this.planeDeform = null
       	this.clipPolygon = null
			  
			  // Holes
			  var element:fPlane = this.element as fPlane
			  for(var i:Number=0;i<element.holes.length;i++) {
   					element.holes[i].removeEventListener(fHole.OPEN,this.openHole)
				 		element.holes[i].removeEventListener(fHole.CLOSE,this.closeHole)
				 		if(!element.holes[i].open && element.holes[i].block) this.behind.removeChild(element.holes[i].block)				 		 	
			  }

				// Maps
				this.bumpMap = null
				this.diffuse = null
				if(this.diffuseData) this.diffuseData.dispose()
				this.diffuseData = null
				if(this.bumpMapData) this.bumpMapData.dispose()
				this.displacer = null
				this.tMatrix = null
				this.tMatrixB = null

				// Lights
				for(i=0;i<this.lightMasks.length;i++) {
					if(this.lightMasks[i]) this.lightMasks[i].graphics.clear()
					objectPool.returnInstance(this.lightMasks[i])
					delete this.lightMasks[i]
				}
				this.lightMasks = null
				for(i=0;i<this.lightShadowsObj.length;i++) {
					fFlash9RenderEngine.recursiveDelete(this.lightShadowsObj[i])
					objectPool.returnInstance(this.lightShadowsObj[i])
					delete this.lightShadowsObj[i]
				}
				this.lightShadowsObj = null
				for(i=0;i<this.lightShadowsPl.length;i++) {
					fFlash9RenderEngine.recursiveDelete(this.lightShadowsPl[i])
					objectPool.returnInstance(this.lightShadowsPl[i])
					delete this.lightShadowsPl[i]
				}
				this.lightShadowsPl = null
				for(i=0;i<this.lightBumps.length;i++) {
					fFlash9RenderEngine.recursiveDelete(this.lightBumps[i])
					objectPool.returnInstance(this.lightBumps[i])
					delete this.lightBumps[i]
				}
				this.lightBumps = null
				for(i=0;i<this.lightClips.length;i++) {
					objectPool.returnInstance(this.lightClips[i])
					fFlash9RenderEngine.recursiveDelete(this.lightClips[i])
					delete this.lightClips[i]
				}
				this.lightClips = null
				for(var j in this.lightStatuses) {
					var light:fLight =this.lightStatuses[j].light
		 		  light.removeEventListener(fLight.INTENSITYCHANGE,this.processLightIntensityChange)
		 		  light.removeEventListener(fLight.COLORCHANGE,this.processLightIntensityChange)
		 		  light.removeEventListener(fLight.DECAYCHANGE,this.processLightIntensityChange)
					delete this.lightStatuses[j]
				}
				this.lightStatuses = null


				// Occlusion
				for(j in this.occlusionSpots) {
					fFlash9RenderEngine.recursiveDelete(this.occlusionSpots[j])
					delete this.occlusionSpots[j]
				}
				this.occlusionSpots = null

				fFlash9RenderEngine.recursiveDelete(this.deformedSimpleShadowsLayer)
				fFlash9RenderEngine.recursiveDelete(this.simpleShadowsLayer)
				fFlash9RenderEngine.recursiveDelete(this.occlusionLayer)
				this.deformedSimpleShadowsLayer = null
				this.simpleShadowsLayer = null
				this.occlusionLayer = null


				// Return to object pool
				fFlash9RenderEngine.recursiveDelete(this.baseContainer)
				objectPool.returnInstance(this.baseContainer)
				objectPool.returnInstance(this.behind)
				objectPool.returnInstance(this.infront)
			  objectPool.returnInstance(this.lightC)
			  objectPool.returnInstance(this.simpleHolesC)
				objectPool.returnInstance(this.deformedSimpleShadowsLayer)
				objectPool.returnInstance(this.simpleShadowsLayer)
				objectPool.returnInstance(this.occlusionLayer)

				// Base lights
				this.behind = null
				this.infront = null
			  this.finalBitmap = null
				if(this.finalBitmapData) this.finalBitmapData.dispose()
				this.finalBitmapData = null
			  this.lightC = null
			  this.simpleHolesC = null
				this.black = null
			  this.environmentC = null
				this.baseContainer = null
				this.spriteToDraw = null

				this.disposeRenderer()
				
			}

			/** @private */
			public override function dispose():void {
				this.disposePlaneRenderer()
			}

		}

}
