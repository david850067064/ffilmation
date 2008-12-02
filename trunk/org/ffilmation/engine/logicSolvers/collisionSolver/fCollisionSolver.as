// Character class
package org.ffilmation.engine.logicSolvers.collisionSolver {
	
		// Imports
		import flash.geom.Point
		import org.ffilmation.utils.*
		import org.ffilmation.engine.core.*
		import org.ffilmation.engine.datatypes.*
		import org.ffilmation.engine.helpers.*
		import org.ffilmation.engine.elements.*
		import org.ffilmation.engine.events.*
		import org.ffilmation.engine.logicSolvers.collisionSolver.collisionModels.*

		/** 
		* This class constains all methods related to collision detection and solving.
		* @private
		*/
		public class fCollisionSolver {

			/** 
			* This methods tests a character's collisions at its current position, generates collision events (if any)
			* and moves the character into a valid position if necessary.
			* dx,dy and dz indicate the direction of the character and are useful to optimize tests
			*/
			public static function solveCharacterCollisions(character:fCharacter,dx:Number,dy:Number,dz:Number):void {
			
		 		var scene:fScene = character.scene
		 		var testCell:fCell,testElement:fRenderableElement, confirm:fCollision
		 		var primaryCandidates:Array = new Array
		 		var secondaryCandidates:Array = new Array
		 		var radius:Number = character.radius
		 		
			 	// Test against floors
			 	if(dz<0) {
					
					try {
						if(character.z>0) {
							testCell = scene.translateToCell(character.x,character.y,character.z)
							if(testCell.walls.top) primaryCandidates[primaryCandidates.length] = (testCell.walls.top)
						} else {
							character.z = 0
							testCell = scene.translateToCell(character.x,character.y,0)
							primaryCandidates[primaryCandidates.length] = (testCell.walls.bottom)
						}
					
			 			if(testCell.walls.up) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.up)
			 			if(testCell.walls.down) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.down)
			 			if(testCell.walls.left) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.left)
			 			if(testCell.walls.right) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.right)

			 			var nchars:Number = testCell.charactersOccupying.length
			 			for(k=0;k<nchars;k++) if(testCell.charactersOccupying[k]!=character && testCell.charactersOccupying[k]._visible) secondaryCandidates[secondaryCandidates.length] = (testCell.charactersOccupying[k])
			 			
			 			var nobjects:Number = testCell.walls.objects.length
			 			for(var k:Number=0;k<nobjects;k++) if(testCell.walls.objects[k]._visible) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.objects[k])
			 			
					} catch (e:Error) {
						primaryCandidates = new Array
		 				secondaryCandidates = new Array
					}
        
				}
				
				if(dz>0) {
					
					try {
						testCell = scene.translateToCell(character.x,character.y,character.z+character.height)
						if(testCell.walls.bottom) primaryCandidates[primaryCandidates.length] = (testCell.walls.bottom)	
			 			
			 			if(testCell.walls.up) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.up)
			 			if(testCell.walls.down) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.down)
			 			if(testCell.walls.left) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.left)
			 			if(testCell.walls.right) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.right)
			 			
			 			nchars = testCell.charactersOccupying.length
			 			for(k=0;k<nchars;k++) if(testCell.charactersOccupying[k]!=character && testCell.charactersOccupying[k]._visible) secondaryCandidates[secondaryCandidates.length] = (testCell.charactersOccupying[k])
			 			
			 		  nobjects = testCell.walls.objects.length
			 		  for(k=0;k<nobjects;k++) if(testCell.walls.objects[k]._visible) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.objects[k])
        
					} catch (e:Error) {
					}
					
				}
				
				var l:Number
				l = primaryCandidates.length
				var some:Boolean = false
				for(var j:Number=0;j<l;j++) {
					testElement = primaryCandidates[j]
					confirm = fCollisionSolver.testPrimaryCollision(character,testElement,dx,dy,dz)
		  	  if(confirm!=null) {
		  	  	
		  	  	if(testElement.solid) {
		  	  		some = true
 							character.z = confirm.z
 							character.top = character.z+character.height
	 						character.dispatchEvent(new fCollideEvent(fCharacter.COLLIDE,testElement))
	 					} else {
	 						character.dispatchEvent(new fWalkoverEvent(fCharacter.WALKOVER,testElement))
	 					}
		 			}
					
				}
        
				// If no primary fCollisions were confirmed, test secondary
				if(!some) {
					
					// Test secondary fCollisions
				  l = secondaryCandidates.length
					for(j=0;j<l;j++) {
						testElement = secondaryCandidates[j]
						confirm = fCollisionSolver.testSecondaryCollision(character,testElement,dx,dy,dz)
		  	  	if(confirm!=null && confirm.z>=0) {
		  	  		
			  	  	if(testElement.solid) {
 								character.z = confirm.z
 								character.top = character.z+character.height
 								character.dispatchEvent(new fCollideEvent(fCharacter.COLLIDE,testElement))
 							} else {
 								character.dispatchEvent(new fWalkoverEvent(fCharacter.WALKOVER,testElement))
 							}
 								
 						}
					}
					
				}
				
				// Retrieve list of possible walls. Separate between primary and secondary
				primaryCandidates = new Array
				secondaryCandidates = new Array
				var tz:Number
				
				if(dx<0) {
					
					try {
						for(tz=character.z;tz<=character.top;tz+=scene.levelSize) {
							testCell = scene.translateToCell(character.x-radius,character.y,tz)
							if(testCell.walls.right) primaryCandidates[primaryCandidates.length] = (testCell.walls.right)

			 				nchars = testCell.charactersOccupying.length
			 				for(k=0;k<nchars;k++) if(testCell.charactersOccupying[k]!=character && testCell.charactersOccupying[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.charactersOccupying[k])
			 				
			 				nobjects = testCell.walls.objects.length
			 				for(k=0;k<nobjects;k++) if(testCell.walls.objects[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.walls.objects[k])
          		
							if(testCell.walls.up && testCell.walls.up.y>(character.y-radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.up)
							if(testCell.walls.down && testCell.walls.down.y<(character.y+radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.down)
							if(testCell.walls.top && testCell.walls.top.z<character.top) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.top)
							if(testCell.walls.bottom && testCell.walls.bottom.z>character.z) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.bottom)
						}
					} catch (e:Error) {
						// This means we went outside scene limits and found a null cell. We return a false wall to simulate a collision
						var gs:int = scene.gridSize
						var tx:int = int(character.x/gs)*gs
						var ty:int = int(character.y/gs)*gs
						var gh:int = scene.height
						primaryCandidates[primaryCandidates.length] = (new fWall(<wall x={tx} y={ty} size={gs} height={gh} z={0} direction={"vertical"} />,scene))
					}	
					
        
				}
        
				if(dx>0) {
					
					try {
						for(tz=character.z;tz<=character.top;tz+=scene.levelSize) {
							testCell = scene.translateToCell(character.x+radius,character.y,tz)
							if(testCell.walls.left) primaryCandidates[primaryCandidates.length] = (testCell.walls.left)

			 				nchars = testCell.charactersOccupying.length
			 				for(k=0;k<nchars;k++) if(testCell.charactersOccupying[k]!=character && testCell.charactersOccupying[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.charactersOccupying[k])
          		
			 				nobjects = testCell.walls.objects.length
			 				for(k=0;k<nobjects;k++) if(testCell.walls.objects[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.walls.objects[k])
          		
							if(testCell.walls.up && testCell.walls.up.y>(character.y-radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.up)
							if(testCell.walls.down && testCell.walls.down.y<(character.y+radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.down)
							if(testCell.walls.top && testCell.walls.top.z<character.top) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.top)
							if(testCell.walls.bottom && testCell.walls.bottom.z>character.z) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.bottom)
						}
					} catch (e:Error) {
						// This means we went outside scene limits and found a null cell. We return a false wall to simulate a collision
						gs = scene.gridSize
						tx = (int(character.x/gs)+1)*gs
						ty = int(character.y/gs)*gs
						gh = scene.height
						primaryCandidates[primaryCandidates.length] = (new fWall(<wall x={tx} y={ty} size={gs} height={gh} z={0} direction={"vertical"} />,scene))
					}
        
				}
        
				if(dy<0) {
					
					try {
						for(tz=character.z;tz<=character.top;tz+=scene.levelSize) {
							testCell = scene.translateToCell(character.x,character.y-radius,tz)
							if(testCell.walls.down) primaryCandidates[primaryCandidates.length] = (testCell.walls.down)

			 				nchars = testCell.charactersOccupying.length
			 				for(k=0;k<nchars;k++) if(testCell.charactersOccupying[k]!=character && testCell.charactersOccupying[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.charactersOccupying[k])
         		
			 				nobjects = testCell.walls.objects.length
			 				for(k=0;k<nobjects;k++) if(testCell.walls.objects[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.walls.objects[k])
          		
							if(testCell.walls.left && testCell.walls.left.x>(character.x-radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.left)
							if(testCell.walls.right && testCell.walls.right.x<(character.x+radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.right)
							if(testCell.walls.top && testCell.walls.top.z<character.top) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.top)
							if(testCell.walls.bottom && testCell.walls.bottom.z>character.z) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.bottom)
						}
					} catch (e:Error) {
						// This means we went outside scene limits and found a null cell. We return a false wall to simulate a collision
						gs = scene.gridSize
						tx = int(character.x/gs)*gs
						ty = int(character.y/gs)*gs
						gh = scene.height
						primaryCandidates[primaryCandidates.length] = (new fWall(<wall x={tx} y={ty} size={gs} height={gh} z={0} direction={"horizontal"} />,scene))
					}
				
				}
        
				if(dy>0) {
					
					try {
						for(tz=character.z;tz<=character.top;tz+=scene.levelSize) {
							testCell = scene.translateToCell(character.x,character.y+radius,tz)
							if(testCell.walls.up) primaryCandidates[primaryCandidates.length] = (testCell.walls.up)
            	
			 				nchars = testCell.charactersOccupying.length
			 				for(k=0;k<nchars;k++) if(testCell.charactersOccupying[k]!=character && testCell.charactersOccupying[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.charactersOccupying[k])
            	
			 		  	nobjects = testCell.walls.objects.length
			 		  	for(k=0;k<nobjects;k++) if(testCell.walls.objects[k]._visible) primaryCandidates[primaryCandidates.length] = (testCell.walls.objects[k])
            	
							if(testCell.walls.left && testCell.walls.left.x>(character.x-radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.left)
							if(testCell.walls.right && testCell.walls.right.x<(character.x+radius)) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.right)
							if(testCell.walls.top && testCell.walls.top.z<character.top) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.top)
							if(testCell.walls.bottom && testCell.walls.bottom.z>character.z) secondaryCandidates[secondaryCandidates.length] = (testCell.walls.bottom)
						}
					} catch (e:Error) {
						// This means we went outside scene limits and found a null cell. We return a false wall to simulate a collision
						gs = scene.gridSize
						tx = int(character.x/gs)*gs
						ty = (int(character.y/gs)+1)*gs
						gh = scene.height
						primaryCandidates[primaryCandidates.length] = (new fWall(<wall x={tx} y={ty} size={gs} height={gh} z={0} direction={"horizontal"} />,scene))
					}
        
				}
        
				// Make primary unique
				var temp:Array = new Array
				l = primaryCandidates.length
				for(j=0;j<l;j++) if(temp.indexOf(primaryCandidates[j])<0) temp[temp.length] = primaryCandidates[j]
				primaryCandidates = temp
				l = primaryCandidates.length
				
				// Test primary fCollisions
				some = false
				for(j=0;j<l;j++) {
					
					testElement = primaryCandidates[j]
					confirm = fCollisionSolver.testPrimaryCollision(character,testElement,dx,dy,dz)
		  	  if(confirm!=null) {
		  	  	
		  	  	if(testElement.solid) {
		  	  		some = true
	 						if(confirm.x>=0) character.x = confirm.x
	 						if(confirm.y>=0) character.y = confirm.y

	 						character.dispatchEvent(new fCollideEvent(fCharacter.COLLIDE,testElement))
	 					} else {
	 						character.dispatchEvent(new fWalkoverEvent(fCharacter.WALKOVER,testElement))
	 					}
	 					
		 			}
					
				}
				
				// If no primary fCollisions were confirmed, test secondary
				if(!some) {
        
					// Make secondary unique
					temp = new Array
					l = secondaryCandidates.length
					for(j=0;j<l;j++) if(temp.indexOf(secondaryCandidates[j])<0) temp[temp.length] = secondaryCandidates[j]
					secondaryCandidates = temp
					l = secondaryCandidates.length
        
					// Test secondary fCollisions
					for(j=0;j<l;j++) {
						
						testElement = secondaryCandidates[j]
						confirm = fCollisionSolver.testSecondaryCollision(character,testElement,dx,dy,dz)
		  		  if(confirm!=null) {
		  		  	
		  	  		if(testElement.solid) {
		  	  			some = true
	 							if(confirm.x>=0) character.x = confirm.x
	 							if(confirm.y>=0) character.y = confirm.y
	 							character.dispatchEvent(new fCollideEvent(fCharacter.COLLIDE,testElement))
	 						} else {
	 							character.dispatchEvent(new fWalkoverEvent(fCharacter.WALKOVER,testElement))
	 						}
		 				}
						
					}
					
				}
			
			}
		
			/** 
			* This methods tests a point's collision against an element in the scene
			* @return A boolean result
			*/
			public static function testPointCollision(x:Number,y:Number,z:Number,element:fRenderableElement):Boolean {
				
				if(element is fFloor) return fCollisionSolver.testFloorPointCollision(x,y,z,element as fFloor)
				if(element is fWall) return fCollisionSolver.testWallPointCollision(x,y,z,element as fWall)
				if(element is fObject) return fCollisionSolver.testObjectPointCollision(x,y,z,element as fObject)
				return false
					
			}

			/** 
			* This methods tests a point's collision against a Floor
			* @return A boolean result
			*/
			public static function testFloorPointCollision(x:Number,y:Number,z:Number,floor:fFloor):Boolean {

				if(!floor.solid) return false
				
				// Loop through holes and see if point is inside one
				for(var h:int=0;h<floor.holes.length;h++) {
				
					 	if(floor.holes[h].open) {
						 	var hole:fPlaneBounds = floor.holes[h].bounds
						 	if(hole.x<=x && (hole.x+hole.width)>=x && hole.y<=y && (hole.y+hole.height)>=y) {
							 		return false
						 	}
			 	  	}
				}				

				return true

			}

			/** 
			* This methods tests a point's collision against a wall
			* @return A boolean result
			*/
			public static function testWallPointCollision(x:Number,y:Number,z:Number,wall:fWall):Boolean {

				if(!wall.solid) return false
				
				// Loop through holes and see if point is inside one
				if(wall.vertical) {
					for(var h:int=0;h<wall.holes.length;h++) {
					
						 	if(wall.holes[h].open) {
							 	var hole:fPlaneBounds = wall.holes[h].bounds
							 	if(hole.z<=z && hole.top>=z && hole.y0<=y && hole.y1>=y) {
							 		return false
							 	}
			 				}	  	
					}				
			  } else {
					for(h=0;h<wall.holes.length;h++) {
					
						 	if(wall.holes[h].open) {
							 	hole = wall.holes[h].bounds
							 	if(hole.z<=z && hole.top>=z && hole.x0<=x && hole.x1>=x) {
							 		return false
							 	}
			 				}	  	
					}				
			  }
				
				return true

			}

			/** 
			* This methods tests a point's collision against an object
			* @return A boolean result
			*/
			public static function testObjectPointCollision(x:Number,y:Number,z:Number,obj:fObject):Boolean {

					if(!obj.solid) false
					
					// Above or below the object
					if(z<obj.z || z>=obj.top) return false
					
					// Must check radius
					return (mathUtils.distance(obj.x,obj.y,x,y)<obj.radius)

			}


			/** 
			* This methods tests a character's primary Collisions at its current position against another element in the scene
			* @return A collision object if any collision was found, null otherwise
			*/
			public static function testPrimaryCollision(character:fCharacter,element:fRenderableElement,dx:Number,dy:Number,dz:Number):fCollision {
				
				if(element is fFloor) return fCollisionSolver.testFloorPrimaryCollision(character,element as fFloor,dx,dy,dz)
				if(element is fWall) return fCollisionSolver.testWallPrimaryCollision(character,element as fWall,dx,dy,dz)
				if(element is fObject) return fCollisionSolver.testObjectPrimaryCollision(character,element as fObject,dx,dy,dz)
				return null
				
			}

			/** 
			* This methods tests a character's secondary Collisions at its current position against another element in the scene
			* @return A collision object if any collision was found, null otherwise
			*/
			public static function testSecondaryCollision(character:fCharacter,element:fRenderableElement,dx:Number,dy:Number,dz:Number):fCollision {
				
				if(element is fFloor) return fCollisionSolver.testFloorSecondaryCollision(character,element as fFloor,dx,dy,dz)
				if(element is fWall) return fCollisionSolver.testWallSecondaryCollision(character,element as fWall,dx,dy,dz)
				if(element is fObject) return fCollisionSolver.testObjectSecondaryCollision(character,element as fObject,dx,dy,dz)
				return null
					
			}


			/* 
			* Test primary fCollision from an object into a floor
			* @return A collision object if any collision was found, null otherwise
			*/
			private static function testFloorPrimaryCollision(obj:fObject,floor:fFloor,dx:Number,dy:Number,dz:Number):fCollision {
				
				if(obj.z>floor.z || obj.top<floor.z) return null
				
				var x:Number, y:Number
				x = obj.x
				y = obj.y

				// Loop through holes and see if point is inside one
				for(var h:int=0;h<floor.holes.length;h++) {
				
					 	if(floor.holes[h].open) {
						 	var hole:fPlaneBounds = floor.holes[h].bounds
						 	if(hole.width>=(2*obj.radius) && hole.height>=obj.height && hole.x<=x && (hole.x+hole.width)>=x && hole.y<=y && (hole.y+hole.height)>=y) {
							 		return null
						 	}
			 			}  	
				}				

				// Return fCollision point
				if(dz>0) return new fCollision(-1,-1,floor.z-obj.height-0.01)
				else return new fCollision(-1,-1,floor.z+0.01)
				
			}

			/* 
			* Test primary fCollision from an object into a wall
			* @return A collision object if any collision was found, null otherwise
			*/
			private static function testWallPrimaryCollision(obj:fObject,wall:fWall,dx:Number,dy:Number,dz:Number):fCollision {
				
				var x:Number, y:Number, z:Number, z2:Number
				var any:Boolean
				var radius:Number = obj.radius

				if(wall.vertical) {
					
					if(dx>0 && (obj.x>wall.x || ((obj.x+radius)<wall.x)) ) return null
					if(dx<0 && (obj.x<wall.x || ((obj.x-radius)>wall.x)) ) return null
					
					y = obj.y
					z = obj.z
					z2 = obj.top

					// Loop through holes and see if bottom point is inside one
					any = false
					for(var h:int=0;!any && h<wall.holes.length;h++) {
					
						 	if(wall.holes[h].open) {
						 		var hole:fPlaneBounds = wall.holes[h].bounds
						 		if(hole.width>=(2*obj.radius) && hole.height>=obj.height) {
						 			if(hole.z<=z && hole.top>=z && hole.y0<=y && hole.y1>=y && hole.z<=z2 && hole.top>=z2) any = true
						 		} 
						 	}
			 		  	
					}
					
					// There was a fCollision 
					if(!any) {
						if(dx>0) return new fCollision(wall.x-radius-0.01,-1,-1)
						else return new fCollision(wall.x+radius+0.01,-1,-1)
					}
	
					return null

			  } else {
			  	
					if(dy>0 && (obj.y>wall.y || ((obj.y+radius)<wall.y)) ) return null
					if(dy<0 && (obj.y<wall.y || ((obj.y-radius)>wall.y)) ) return null
					
					x = obj.x
					z = obj.z
					z2 = obj.top

					// Loop through holes and see if bottom point is inside one
					any = false
					for(h=0;!any && h<wall.holes.length;h++) {
					
						 	if(wall.holes[h].open) {
						 		hole = wall.holes[h].bounds
						 		if(hole.width>=(2*obj.radius) && hole.height>=obj.height) {
						 			 if(hole.z<=z && hole.top>=z && hole.z<=z2 && hole.top>=z2 && hole.x0<=x && hole.x1>=x) any = true
						 		}
						 	}
			 		  	
					}
					
					// There was a fCollision 
					if(!any) {
						if(dy>0) return new fCollision(-1,wall.y-radius-0.01,-1)
						else return new fCollision(-1,wall.y+radius+0.01,-1)
					}

					return null

			  }

			}


			/* 
			* Test primary fCollision from an object into another object
			* @return A collision object if any collision was found, null otherwise
			*/
			private static function testObjectPrimaryCollision(obj:fObject,other:fObject,dx:Number,dy:Number,dz:Number):fCollision {
				
				// Simple case. This works now, but it wouldn't with sphere collision models, for example
				if(other.top<obj.z || other.z>obj.top) return null

				// The generic implementation of other test works with any collisionModel
				// But as cilinders allow a more efficient detection, I've programmed specific
				// algorythms for these cases
				if(obj.collisionModel is fCilinderCollisionModel) {
				
					if(other.collisionModel is fCilinderCollisionModel) {
						
						// Both elements use cilinder model
						var distance:Number = mathUtils.distance(obj.x,obj.y,other.x,other.y)
						var impulse:Number = (other.radius+obj.radius)
						if(distance<impulse) {
						
						  impulse*=1.01
						  var angle:Number = mathUtils.getAngle(other.x,other.y,obj.x,obj.y,distance)*Math.PI/180
							return new fCollision(other.x+impulse*Math.cos(angle),other.y+impulse*Math.sin(angle),-1)
							
						} else return null
				
			  	} else {
			  		
			  	  // Only the moving object uses cilinder model. Note that collisionModels use local coordinates. Therefore
			  	  // any point that is to be tested needs to be translated to the model's coordinate origin.
						angle = mathUtils.getAngle(other.x,other.y,obj.x,obj.y)*Math.PI/180
						var cos:Number = -obj.radius*Math.cos(angle)
						var sin:Number = -obj.radius*Math.sin(angle)
						var nx:Number = obj.x+cos
						var ny:Number = obj.y+sin
						
						if(other.collisionModel.testPoint(nx-other.x,ny-other.y,0)) {
							
							var oppositex:Number = obj.x-cos-other.x
							var oppositey:Number = obj.y-sin-other.y
							var nx2:Number = nx-other.x
							var ny2:Number = ny-other.y
							
							// Find out collision point.
							var points:Array = other.collisionModel.getTopPolygon()
							var intersect:Point = null
							for(var i:Number=0;intersect==null && i<points.length;i++) {
								
								if(i==0) intersect = mathUtils.segmentsIntersect(nx2,ny2,oppositex,oppositey,points[0].x,points[0].y,points[points.length-1].x,points[points.length-1].y)
								else intersect = mathUtils.segmentsIntersect(nx2,ny2,oppositex,oppositey,points[i].x,points[i].y,points[i-1].x,points[i-1].y)
								
							}
							

							// This shouldn't happen
							if(intersect==null) return null
							
							// Bounce
							nx = obj.x-(nx2-intersect.x)*1.01
							ny = obj.y-(ny2-intersect.y)*1.01
							
							return new fCollision(nx,ny,-1)
							
						} else return null
			  		
			  		
			  	}
			  	
			  } else {
			  	
			  	// Use generic collision test. Pending implementation
			  	return null
			  	
			  }
			  				
			}


			/* 
			* Test secondary fCollision from an object into a floor
			* @return A collision object if any collision was found, null otherwise
			*/
			private static function testFloorSecondaryCollision(obj:fObject,floor:fFloor,dx:Number,dy:Number,dz:Number):fCollision {
				return null
			}


			/* 
			* Test secondary fCollision from an object into a wall
			* @return A collision object if any collision was found, null otherwise
			*/
			private static function testWallSecondaryCollision(obj:fObject,wall:fWall,dx:Number,dy:Number,dz:Number):fCollision {
				
				var x:Number, y:Number, z:Number
				var any:Boolean, ret:fCollision

				var radius:Number = obj.radius
				var oheight:Number = obj.height

				if(wall.vertical) {
					
					// Are we inside the wall ? Then we must be in a hole
					if( ((obj.x+obj.radius)<wall.x) || ((obj.x-radius)>wall.x) ) return null
					
					y = obj.y
					x = obj.x
					z = (obj.z+obj.top)/2

					// Loop through holes find which one are we inside of
					any = false
					for(var h:int=0;!any && h<wall.holes.length;h++) {
					
						 	if(wall.holes[h].open) {
							 	var hole:fPlaneBounds = wall.holes[h].bounds
							 	if(hole.width>=(2*obj.radius) && hole.height>=obj.height && hole.z<=z && hole.top>=z && hole.y0<=y && hole.y1>=y) {
							 		any = true
							 	} 
							}
			 		  	
					}
					
					// We are inside one
					if(any) {
						
						ret = new fCollision(-1,-1,-1)
						if(dy<0 && ((y-radius)<hole.y0)) ret.y = hole.y0+radius+0.01
						if(dy>0 && ((y+radius)>hole.y1)) ret.y = hole.y1-radius-0.01
						if(dz<0 && obj.z<=hole.z) ret.z = hole.z+0.01
						if(dz>0 && obj.top>=hole.top) ret.z = hole.top-oheight-0.01
						return ret
						
					} else return null

			  } else {
			  	
					// Are we inside the wall ? Then we must be in a hole
					if( ((obj.y+radius)<wall.y) || ((obj.y-radius)>wall.y) ) return null
					
					y = obj.y
					x = obj.x
					z = (obj.z+obj.top)/2

					// Loop through holes and find which one are we inside of
					any = false
					for(h=0;!any && h<wall.holes.length;h++) {
					
						 	if(wall.holes[h].open) {
							 	hole = wall.holes[h].bounds
							 	if(hole.width>=(2*obj.radius) && hole.height>=obj.height && hole.z<=z && hole.top>=z && hole.x0<=x && hole.x1>=x) {
							 		any = true
							 	}
							}
			 		  	
					}
					
					// We are inside one
					if(any) {
						
						ret = new fCollision(-1,-1,-1)
						if(dx<0 && ((x-radius)<hole.x0)) ret.x = hole.x0+radius+0.01
						if(dx>0 && ((x+radius)>hole.x1)) ret.x = hole.x1-radius-0.01
						if(dz<0 && obj.z<=hole.z) ret.z = hole.z+0.01
						if(dz>0 && obj.top>=hole.top) ret.z = hole.top-oheight-0.01
						return ret
						
					} else return null

			  }
				
			}


			/* 
			* Test secondary fCollision from an object into another object
			* @return A collision object if any collision was found, null otherwise
			*/
			private static function testObjectSecondaryCollision(obj:fObject,other:fObject,dx:Number,dy:Number,dz:Number):fCollision {
				
				if(obj.z>other.top || obj.top<other.z) return null
				
				// The generic implementation of other test works with any collisionModel
				// But as cilinders allow a more efficient detection, I've programmed specific
				// algorythms for these cases
				if(obj.collisionModel is fCilinderCollisionModel) {
				
					if(other.collisionModel is fCilinderCollisionModel) {
					
						// Both elements use cilinder model
						if(mathUtils.distance(obj.x,obj.y,other.x,other.y)>=(other.radius+obj.radius)) return null
						
			  	} else {
			  		
			  	  // Only the moving object uses cilinder model. Note that collisionModels use local coordinates. Therefore
			  	  // any point that is to be tested needs to be translated to the model's coordinate origin.
						var angle:Number = mathUtils.getAngle(other.x,other.y,obj.x,obj.y)*Math.PI/180
						var cos:Number = -obj.radius*Math.cos(angle)
						var sin:Number = -obj.radius*Math.sin(angle)
						var nx:Number = obj.x+cos
						var ny:Number = obj.y+sin
						
						if(!other.collisionModel.testPoint(nx-other.x,ny-other.y,0)) return null
			  		
			  	}
			  	
			  } else {
			  	
			  	// Use generic collision test. Pending implementation
			  	
			  	return null
			  	
			  }

				if(obj.z<other.top && obj.top>other.z && (obj.z-dz)>other.top) return new fCollision(-1,-1,other.top+0.01)
				if(obj.top>other.z && obj.z<other.z && (obj.top-dz)<other.z) return new fCollision(-1,-1,other.z-0.01)

				return null

				
			}

		}

}
