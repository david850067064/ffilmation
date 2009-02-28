// Character class
package org.ffilmation.engine.logicSolvers.visibilitySolver {
	
		// Imports
		import flash.geom.*
		
		import org.ffilmation.engine.core.*
		import org.ffilmation.engine.elements.*
		import org.ffilmation.engine.logicSolvers.coverageSolver.*

		/** 
		* This class calculates visibilities: what is visible from a certain point, is element A visible from object B...
		* @private
		*/
		public class fVisibilitySolver {


			/**
			* Calculates elements visible given coordinates, sorted by distance.
			*
			* @param scene The scene we are calculating for
			* @param x X coordinate from where we are "looking"
			* @param y Y coordinate from where we are "looking"
			* @param z Z coordinate from where we are "looking"
			* @param range Elements further away than scene distance are not taken into account. This optimizes the process
			*
			* @return An Array of fVisibilityInfo objects
			*/
			public static function calcVisibles(scene:fScene,x:Number,y:Number,z:Number,range:Number=Infinity):Array {
			
			   // Init
			   var rcell:Array = new Array, candidates:Array = new Array, floorc:fFloor, dist:Number, w:int, len:int, wallc:fWall, objc:fObject
			   var p2d:Point = fScene.translateCoords(x,y,z)
			   
			   // Add floors
			   len = scene.floors.length
			   for(w=0;w<len;w++) {
			      floorc = scene.floors[w] 
			      dist = floorc.distance2dScreen(p2d.x,p2d.y)
			      if(dist<range) candidates[candidates.length] = new fVisibilityInfo(floorc,dist)
			   }
			
			   // Add walls
			   len = scene.walls.length
			   for(w=0;w<len;w++) {
			      wallc = scene.walls[w]
			      dist = wallc.distance2dScreen(p2d.x,p2d.y)
			      if(dist<range) candidates[candidates.length] = new fVisibilityInfo(wallc,dist)
			   }
			
				 // Add objects
				 len = scene.objects.length
			   for(w=0;w<len;w++) {
			      objc = scene.objects[w]
			      dist = objc.distance2dScreen(p2d.x,p2d.y)
			      if(dist<range) candidates[candidates.length] = new fVisibilityInfo(objc,dist)
			   }

			   // Sort results by distance to coords 
	       candidates.sortOn("distance",Array.NUMERIC)	
			   return candidates      
			
			}


			/**
			* Calculates elements affected by lights at given coordinates, sorted by distance. For each element visible, elements casting shadows into it are
			* also returned
			*
			* @param scene The scene we are calculating for
			* @param x X coordinate from where we are "looking"
			* @param y Y coordinate from where we are "looking"
			* @param z Z coordinate from where we are "looking"
			* @param range Elements further away than scene distance are not taken into account. This optimizes the process
			*
			* @return An Array of fShadowedVisibilityInfo objects
			*/
			public static function calcAffectedByLight(scene:fScene,x:Number,y:Number,z:Number,range:Number=Infinity):Array {
			
			   // Init
			   var rcell:Array = new Array, candidates:Array = new Array, allElements:Array = new Array, floorc:fFloor, dist:Number, w:Number, len:Number, wallc:fWall, objc:fObject

			   // Add possible floors
			   len = scene.floors.length
			   for(w=0;w<len;w++) {
			      floorc = scene.floors[w] 
			      dist = floorc.distanceTo(x,y,z)
			      if(dist<range) {
			      	if(floorc.receiveLights) if(floorc.z<z) candidates[candidates.length] = (new fShadowedVisibilityInfo(floorc,dist))
			      	if(floorc.castShadows) allElements[allElements.length] = (new fShadowedVisibilityInfo(floorc,dist))
			      }
			   }
			
			   // Add possible walls
			   len = scene.walls.length
			   for(w=0;w<len;w++) {
			      wallc = scene.walls[w]
			      dist = wallc.distanceTo(x,y,z)
			      if(dist<range) {
			      	if(wallc.receiveLights) if((wallc.vertical && wallc.x>x) || (!wallc.vertical && wallc.y<y)) candidates[candidates.length] = (new fShadowedVisibilityInfo(wallc,dist))
					  	if(wallc.castShadows) allElements[allElements.length] = (new fShadowedVisibilityInfo(wallc,dist))
					  }
			   }
			
				 // Add possible objects
				 var withObjects:Boolean = fEngine.objectShadows
				 len = scene.objects.length
			   for(w=0;w<len;w++) {
			      objc = scene.objects[w]
			      dist = objc.distanceTo(x,y,z)
			      if(dist<range) {
			      	if(objc.receiveLights) candidates[candidates.length] = (new fShadowedVisibilityInfo(objc,dist))
			      	if(withObjects) if(objc.castShadows) allElements[allElements.length] = (new fShadowedVisibilityInfo(objc,dist))
			      }
			   }

			   // For each candidate, calculate possible shadows
			   var candidate:fShadowedVisibilityInfo, covered:Boolean, other:fShadowedVisibilityInfo, result:int, len2:Number

			   len = candidates.length
			   for(w=0;w<len;w++) {
			      
			      candidate = candidates[w]
			      covered = false
			      len2 = allElements.length
			      
			      // Shadows from other elements
			      if(candidate.obj.receiveShadows) {
			      	
			      	for(var k:Number=0;covered==false && k<len2;k++) {
			      	   other = allElements[k]
			      	   if(candidate.obj!=other.obj) {
			      	      result = fCoverageSolver.calculateCoverage(other.obj,candidate.obj,x,y,z)
			      	   	  //trace("Test "+candidate.obj.id+" "+other.obj.id+" "+result)
			      	      switch(result) {
			      	         case fCoverage.COVERED: covered = true;
			      	         case fCoverage.SHADOWED: candidate.addShadow(new fVisibilityInfo(other.obj,other.distance))
			      	      }
			      	   }
			      	}
			      
			      }

			      // If not covered, sort shadows by distance to coords and add candidate to result list
			      if(!covered) { 
			         candidate.shadows.sortOn("distance",Array.NUMERIC)
			         rcell[rcell.length] = candidate
			      }
			
			   }

			   // Sort results by distance to coords 
	       rcell.sortOn("distance",Array.NUMERIC)	
			   return rcell      
			
			}

		}

}
