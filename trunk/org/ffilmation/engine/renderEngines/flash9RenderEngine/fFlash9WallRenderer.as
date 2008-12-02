// WALL

package org.ffilmation.engine.renderEngines.flash9RenderEngine {
	
		// Imports
		import flash.display.*
		import flash.utils.*
		import flash.geom.Point
		import flash.geom.Matrix
		import flash.geom.ColorTransform
		import flash.geom.Rectangle

		import org.ffilmation.utils.*
		import org.ffilmation.engine.core.*
		import org.ffilmation.engine.elements.*
		import org.ffilmation.engine.logicSolvers.projectionSolver.*
		import org.ffilmation.engine.renderEngines.flash9RenderEngine.helpers.*

		/**
		* This class renders a fWall
		* @private
		*/
		public class fFlash9WallRenderer extends fFlash9PlaneRenderer {
			
			// Static properties. Render cache
			private static var objectRenderCache:Dictionary = new Dictionary(true)
			
			// Public properties

			/**
			* This is the tranformation matrix for vertical walls
			*/
			public static var verticalMatrix = new Matrix(0.706974983215332,0.35248100757598877,0,fEngine.DEFORMATION,0,0)	
			
			/**
			* This is the tranformation matrix for horizontal walls
			*/
			public static var horizontalMatrix = new Matrix(0.706974983215332,-0.35248100757598877,0,fEngine.DEFORMATION,0,0)

			// Private properties
	    public var polyClip:Array

			// Constructor
			function fFlash9WallRenderer(rEngine:fFlash9RenderEngine,container:MovieClip,element:fWall):void {
				
				 // Generate Sprites
				 var destination:Sprite = objectPool.getInstanceOf(Sprite) as Sprite
				 container.addChild(destination)

				 // Set specific wall dimensions
				 this.scrollR = new Rectangle(0, 0, element.pixelSize, -element.pixelHeight)
			   if(element.vertical) this.planeDeform = fFlash9WallRenderer.verticalMatrix	
				 else this.planeDeform = fFlash9WallRenderer.horizontalMatrix

				 // Previous
				 super(rEngine,element,element.pixelSize,element.pixelHeight,destination,container)

			   // Create polygon bounds, for clipping algorythm
				 this.polyClip = [ new Point(element.x,element.y0),
				 							     new Point(element.x,element.y1),
				 							     new Point(element.x,element.y1),
				 							     new Point(element.x,element.y0) ]
			   
			
			}
			
			// Methods
		
			/**
			* Gives geometry container the proper dimensions
			*/
			public override function setDimensions(lClip:DisplayObject):void {
				var w:fWall = this.element as fWall
				lClip.width = w.pixelSize
				lClip.height = w.pixelHeight
				lClip.y = -w.pixelHeight
		  }

			/**
			* Place asset its proper position
			*/
			public override function place():void {
			   // Place in position
			   var coords:Point = fScene.translateCoords(this.element.x0,this.element.y0,this.element.z)
			   this.container.x = coords.x
			   this.container.y = coords.y
			}
			
			/**
			* Render ( draw ) light
			*/
			public override function renderLight(light:fLight):void {
					
					var w:fWall = this.element as fWall
					if(w.vertical) this.renderLightVertical(light)
					else this.renderLightHorizontal(light)

		  }
			private function renderLightVertical(light:fLight):void {
			
			   var status:fLightStatus = this.lightStatuses[light.uniqueId]
			   var lClip:Sprite = this.lightClips[light.uniqueId]
			     
			   if(light.size!=Infinity) {
			      
			      // If distance to light changed, redraw masks
			      if(status.lightZ != light.x) {
			      	
			      	 var d:Number = light.x-this.element.x
			      	 this.setLightDistance(light,(d>0)?d:-d)
			         status.lightZ = light.x
			      }
			   }   
			   
			   // Move light
			   this.setLightCoordinates(light,(light.y-this.element.y0),(this.element.z-light.z))
			
			}
			private function renderLightHorizontal(light:fLight):void {
			
			   var status:fLightStatus = this.lightStatuses[light.uniqueId]
			   var lClip:Sprite = this.lightClips[light.uniqueId]
			
			   if(light.size!=Infinity) {
			
			      // If distance to light changed, redraw masks
			      if(status.lightZ != light.y) {
			      	
			      	 var d:Number = light.y-this.element.y
			      	 this.setLightDistance(light,(d>0)?d:-d)
			         status.lightZ = light.y
			      }
			   
			   }
			   
	   	   // Move light
			   this.setLightCoordinates(light,(light.x-this.element.x0),(this.element.z-light.z))
			
			}
			
			/**
			* Calculates and projects shadows upon this wall
			*/
			public override function renderShadowInt(light:fLight,other:fRenderableElement,msk:Sprite):void {
			   if(other is fFloor) this.renderFloorShadow(light,other as fFloor,msk)
			   if(other is fWall) this.renderWallShadow(light,other as fWall,msk)
			   
			   // Walls don't receive shadows from objects in basic shadow quality
			   // or characters in basic and normal shadow quality
			   if(other is fObject) {

			    	// Simple shadows ?
			   		var simpleShadows:Boolean = (other.customData.flash9Renderer as fFlash9ObjectRenderer).simpleShadows

			   		if(!simpleShadows) this.renderObjectShadow(light,other as fObject,msk)
			   		
			   }
			   
			}

			/**
			* Delete element shadows upon this wall
			*/
			public override function removeShadow(light:fLight,other:fRenderableElement):void {
			   
					var o:fCharacter = other as fCharacter
					
			 	 	var cache:Dictionary = fFlash9WallRenderer.objectRenderCache[this.element.uniqueId+"_"+light.uniqueId]
			 	 	var clip:Sprite = cache[other.uniqueId].shadow
			 	 	if(clip.parent) clip.parent.removeChild(clip)
			 	 	
			 	 	this.rEngine.returnObjectShadow(cache[other.uniqueId])
			 	 	delete cache[other.uniqueId]
			 	 	
			}

			/**
			* Calculates and projects shadows of a floor upon this wall
			*/
			public function renderFloorShadow(light:fLight,other:fFloor,msk:Sprite):void {
			
			   var lightStatus:fLightStatus = this.lightStatuses[light.uniqueId] 
			   var x:Number = light.x, y:Number = light.y, z:Number = light.z
			   var len:int,len2:int
			
			   var element:fWall = this.element as fWall
			   msk.graphics.beginFill(0x000000,100)   
				 if(element.vertical) var points:Object = fProjectionSolver.calculateFloorProjectionIntoVerticalWall(element,light.x,light.y,light.z,other.bounds)
				 else points = fProjectionSolver.calculateFloorProjectionIntoHorizontalWall(element,light.x,light.y,light.z,other.bounds)
				 
			   msk.graphics.moveTo(points[0].x,points[0].y)
			   
			   len = points.length
				 for(var i:int=1;i<len;i++) msk.graphics.lineTo(points[i].x,points[i].y)
			
				 // For each hole, draw light
				 len = other.holes.length
				 for(var h:int=0;h<len;h++) {
					 	
					 	if(other.holes[h].open) {
					 		if(element.vertical) points = fProjectionSolver.calculateFloorProjectionIntoVerticalWall(element,light.x,light.y,light.z,other.holes[h].bounds)
					  	else points = fProjectionSolver.calculateFloorProjectionIntoHorizontalWall(element,light.x,light.y,light.z,other.holes[h].bounds)
					 	
				 	  	if(points.length>0) {
					 	  	msk.graphics.moveTo(points[0].x,points[0].y)
				 	  		len2 = points.length
				 	  		for(i=1;i<len2;i++) msk.graphics.lineTo(points[i].x,points[i].y)
				 			}
				 		}
				 }
			
				 msk.graphics.endFill()

			}
			
			/**
			* Calculates and projects shadows of given wall and light
		  */
			public function renderWallShadow(light:fLight,wall:fWall,msk:Sprite):void {
			
			   var lightStatus:fLightStatus = this.lightStatuses[light.uniqueId] 
			   var x:Number = light.x, y:Number = light.y, z:Number = light.z
			   var len:int,len2:int
			
			   var element:fWall = this.element as fWall
			   msk.graphics.beginFill(0x000000,100)   
			
				 try {
				 	
				 		if(element.vertical) var points:Array = fProjectionSolver.calculateWallProjectionIntoVerticalWall(element,light.x,light.y,light.z,wall.bounds)
				 		else points = fProjectionSolver.calculateWallProjectionIntoHorizontalWall(element,light.x,light.y,light.z,wall.bounds)
			   		
				 		// Clipping viewport
				 		var vp:vport = new vport()
				 		vp.x_min = 0
				 		vp.x_max = element.pixelSize
				 		vp.y_min = -element.height
				 		vp.y_max = 0
				 		 
				 		points = polygonUtils.clipPolygon(points,vp)
			   		msk.graphics.moveTo(points[0].x,points[0].y)
			   		len=points.length
				 		for(var i:int=1;i<len;i++) msk.graphics.lineTo(points[i].x,points[i].y)
			   		
			   		
				 		// For each hole, draw light
				 		len = wall.holes.length
				 		for(var h:int=0;h<len;h++) {
			   		
							if(wall.holes[h].open) { 	
							 	if(element.vertical) points = fProjectionSolver.calculateWallProjectionIntoVerticalWall(element,light.x,light.y,light.z,wall.holes[h].bounds)
							  else points = fProjectionSolver.calculateWallProjectionIntoHorizontalWall(element,light.x,light.y,light.z,wall.holes[h].bounds)
							 	
				 				points = polygonUtils.clipPolygon(points,vp)	 
			   		
				 			  if(points.length>0) {
				 			  	msk.graphics.moveTo(points[0].x,points[0].y)
				 			  	len2 = points.length
				 			  	for(i=1;i<len2;i++) msk.graphics.lineTo(points[i].x,points[i].y)
				 				}
				 			}

				 		}
			
				 } catch (e:Error) {
				 	
				 }
				 
				 msk.graphics.endFill()


			}

			/** 
			* Resets shadows. This is called when the fEngine.shadowQuality value is changed
			*/
			public override function resetShadowsInt():void {
				for(var i in fFlash9WallRenderer.objectRenderCache) {
					var a:Dictionary = fFlash9WallRenderer.objectRenderCache[i]
					for(var j in a) {
						 try {
						 	var clip:Sprite = a[j].shadow
						 	clip.parent.removeChild(clip)
							this.rEngine.returnObjectShadow(a[j])
							delete a[j]
						 } catch(e:Error) {
						  trace("Wall reset error: "+e)	
						 }
					}
					delete fFlash9WallRenderer.objectRenderCache[i]
				}
			}

			/**
			* Calculates and projects shadows of objects upon this wall
			*/
			private function renderObjectShadow(light:fLight,other:fObject,msk:Sprite):void {
				 
				 // Too far away ?
				 if((other.z-this.element.z)>fObject.SHADOWRANGE) return

				 // Calculate projection
				 var element:fWall = this.element as fWall
				 var proj:fObjectProjection
				 if(light.z<other.z) proj = this.rEngine.getObjectSpriteProjection(other,element.top,light.x,light.y,light.z)
				 else proj = this.rEngine.getObjectSpriteProjection(other,element.z,light.x,light.y,light.z)
				 
				 if(element.vertical) {
				 		var intersect:Point = mathUtils.linesIntersect(element.x,element.y0,element.x,element.y1,proj.origin.x,proj.origin.y,proj.end.x,proj.end.y)
				 		var intersect2:Point = mathUtils.linesIntersect(element.x,element.z,element.x,element.top,proj.origin.x,element.z,light.x,light.z)
				 		var intersect3:Point = mathUtils.linesIntersect(element.x,element.z,element.x,element.top,proj.end.x,element.z,other.x,other.top)
				 } else {
				 		intersect = mathUtils.linesIntersect(element.x0,element.y,element.x1,element.y,proj.origin.x,proj.origin.y,proj.end.x,proj.end.y)
				 		intersect2 = mathUtils.linesIntersect(element.y,element.z,element.y,element.top,proj.origin.y,element.z,light.y,light.z)
				 		intersect3 = mathUtils.linesIntersect(element.y,element.z,element.y,element.top,proj.end.y,element.z,other.y,other.top)
				 }

				 // If no intersection ( parallell lines ) return
				 if(intersect==null) return
				 
				 // Cache or new Movieclip ?
				 if(!fFlash9WallRenderer.objectRenderCache[element.uniqueId+"_"+light.uniqueId]) {
				 		fFlash9WallRenderer.objectRenderCache[element.uniqueId+"_"+light.uniqueId] = new Dictionary(true)
				 }
				 var cache = fFlash9WallRenderer.objectRenderCache[element.uniqueId+"_"+light.uniqueId]
				 if(!cache[other.uniqueId]) {
				 		cache[other.uniqueId] = this.rEngine.getObjectShadow(other,this.element)
				 		cache[other.uniqueId].shadow.transform.colorTransform = new ColorTransform(0,0,0,1,0,0,0,0)
				 }

				 var distance:Number = (other.z-element.z)/fObject.SHADOWRANGE

				 // Draw
				 var clip:Sprite = cache[other.uniqueId].shadow
				 msk.addChild(clip)
				 clip.alpha = 1-distance
				 
				 if(element.vertical) clip.x = intersect.y-element.y0
				 else clip.x = intersect.x-element.x0

		 		 clip.y = (element.z-intersect2.y)
				 clip.height = (intersect3.y-intersect2.y)*(1+fObject.SHADOWSCALE*distance)
		 		 clip.scaleX = 1+fObject.SHADOWSCALE*distance
				 
			   // Simple shadows ?
			   var simpleShadows:Boolean = (other.customData.flash9Renderer as fFlash9ObjectRenderer).simpleShadows
			   var eraseShadows:Boolean = (other.customData.flash9Renderer as fFlash9ObjectRenderer).eraseShadows

				 // Adjust alpha if necessary
				 if(light.size!=Infinity && !eraseShadows && !simpleShadows) {
				 		var distToLight:Number = mathUtils.distance(light.x,light.y,other.x,other.y)
				 		var distToLightBorder:Number = (this.lightMasks[light.uniqueId].width/2)-distToLight
				 	  if(distToLightBorder<clip.height) {
				 	  	var fade:Number = 1-((clip.height-distToLightBorder)/clip.height)
				 	  	clip.alpha *= fade
				 	  }
				 }


			}

			/**
			* Light leaves element
			*/
			public override function lightOut(light:fLight):void {
			
			   // Hide container
			   if(this.lightStatuses[light.uniqueId]) {
			  	 var lClip:Sprite = this.lightClips[light.uniqueId]
			   	 this.lightC.removeChild(lClip)
			   }
			   
			   // Hide shadows
				 if(fFlash9WallRenderer.objectRenderCache[this.element.uniqueId+"_"+light.uniqueId]) {
				 		var cache:Dictionary = fFlash9WallRenderer.objectRenderCache[this.element.uniqueId+"_"+light.uniqueId]
				 		for(var i in cache) {
				 			try {
				 				cache[i].parent.removeChild(cache[i])
				 			} catch(e:Error) {
				 			
				 			}
				 		}			   
				 }
				 
		 		 this.undoCache(true)
			   
			}

			/**
			* Light is to be reset
			*/
		  public override function lightReset(light:fLight):void {
		  	
		  	this.lightOut(light)
		  	delete this.lightStatuses[light.uniqueId]
		  	delete this.lightClips[light.uniqueId]
		  	delete fFlash9WallRenderer.objectRenderCache[this.element.uniqueId+"_"+light.uniqueId]
		  	
			}

			/** @private */
			public function disposeWallRenderer():void {

				this.polyClip = null
				this.resetShadowsInt()
				this.disposePlaneRenderer()
				
			}

			/** @private */
			public override function dispose():void {
				this.disposeWallRenderer()
			}		


		}

}