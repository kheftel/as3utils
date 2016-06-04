package kheftel.util
{
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.textures.Texture;
	import starling.textures.TextureSmoothing;
	import starling.utils.MatrixUtil;
	import starling.utils.VertexData;
	
	/**
	 * A baseline Starling 1.x custom display object that draws an image.
	 * Basically a reference implementation for making custom display objects
	 */
	public class CustomImage extends Image
	{
		private static var PROGRAM_NAME:String = 'CustomImage';
		
		private var _indexData:Vector.<uint>;
		private var _vertexBuffer:VertexBuffer3D;
		private var _indexBuffer:IndexBuffer3D;
		
		private static var sRenderMatrix:Matrix3D = new Matrix3D();
		private static var sRenderAlpha:Vector.<Number> = new <Number>[1.0, 1.0, 1.0, 1.0];
		private static var sProgramNameCache:Dictionary = new Dictionary();
		
		public function CustomImage(texture:Texture)
		{
			super(texture);
			
			// setup vertex data and prepare shaders
			setupVertices();
			createBuffers();
			
			// handle lost context
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
		
		private function onContextCreated(event:Event):void
		{
			// the old context was lost, so we create new buffers and shaders.
			createBuffers();
		}
		
		/** Creates the required vertex- and index data and uploads it to the GPU. */ 
		private function setupVertices():void
		{
			var i:int;
			
			// vertices created by Quad
			
			// create indices that span up the triangles
			_indexData = new <uint>[0, 1, 2, 1, 3, 2];
		}
		
		private function createBuffers():void
		{
			destroyBuffers();
			
			var numVertices:int = mVertexData.numVertices;
			var numIndices:int = _indexData.length;
			var context:Context3D = Starling.context;
			
			if (numVertices == 0) return;
			if (context == null)  throw new MissingContextError();
			
			_vertexBuffer = context.createVertexBuffer(numVertices, VertexData.ELEMENTS_PER_VERTEX);
			_vertexBuffer.uploadFromVector(mVertexData.rawData, 0, numVertices);
			
			_indexBuffer = context.createIndexBuffer(numIndices);
			_indexBuffer.uploadFromVector(_indexData, 0, numIndices);
		}
		
		private function destroyBuffers():void
		{
			if (_vertexBuffer)
			{
				_vertexBuffer.dispose();
				_vertexBuffer = null;
			}
			
			if (_indexBuffer)
			{
				_indexBuffer.dispose();
				_indexBuffer = null;
			}
		}
		
		private function getProgram():Program3D
		{
			var tinted:Boolean = true;
			
			var target:Starling = Starling.current;
			var programName:String = PROGRAM_NAME;
			
			if (this.texture)
				programName = getImageProgramName(tinted, texture.mipMapping, 
					texture.repeat, texture.format, smoothing);
			
			var program:Program3D = target.getProgram(programName);
			
			if (!program)
			{
				// this is the input data we'll pass to the shaders:
				// 
				// va0 -> position
				// va1 -> color
				// va2 -> texCoords
				// vc0 -> alpha
				// vc1 -> mvpMatrix
				// fs0 -> texture
				
				var vertexShader:String;
				var fragmentShader:String;
				
				if (!texture) // Quad-Shaders
				{
					vertexShader =
						"m44 op, va0, vc1 \n" + // 4x4 matrix transform to output clipspace
						"mul v0, va1, vc0 \n";  // multiply alpha (vc0) with color (va1)
					
					fragmentShader =
						"mov oc, v0       \n";  // output color
				}
				else // Image-Shaders
				{
					vertexShader = tinted ?
						"m44 op, va0, vc1 \n" + // 4x4 matrix transform to output clipspace
						"mul v0, va1, vc0 \n" + // multiply alpha (vc0) with color (va1)
						"mov v1, va2      \n"   // pass texture coordinates to fragment program
						:
						"m44 op, va0, vc1 \n" + // 4x4 matrix transform to output clipspace
						"mov v1, va2      \n";  // pass texture coordinates to fragment program
					
					fragmentShader = tinted ?
						"tex ft1,  v1, fs0 <???> \n" + // sample texture 0
						"mul  oc, ft1,  v0       \n"   // multiply color with texel color
						:
						"tex  oc,  v1, fs0 <???> \n";  // sample texture 0
					
					fragmentShader = fragmentShader.replace("<???>",
						RenderSupport.getTextureLookupFlags(
							texture.format, texture.mipMapping, texture.repeat, smoothing));
				}
				
				program = target.registerProgramFromSource(programName,
					vertexShader, fragmentShader);
			}
			
			return program;
		}
		
		
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{
			support.finishQuadBatch();
			support.raiseDrawCount();
			renderCustom(support.mvpMatrix, alpha * parentAlpha, support.blendMode);
		}
		
		/** Renders the BlurredImage with custom settings for model-view-projection matrix, alpha 
		 *  and blend mode. This makes it possible to render ojects that are not part of the 
		 *  display list. */ 
		public function renderCustom(mvpMatrix:Matrix, parentAlpha:Number=1.0,
									 blendMode:String=null):void
		{
			//if (mNumQuads == 0) return;
			//if (mSyncRequired) syncBuffers();
			
			var pma:Boolean = mVertexData.premultipliedAlpha;
			var context:Context3D = Starling.context;
			var tinted:Boolean = true;//mTinted || (parentAlpha != 1.0);
			
			sRenderAlpha[0] = sRenderAlpha[1] = sRenderAlpha[2] = pma ? parentAlpha : 1.0;
			sRenderAlpha[3] = parentAlpha;
			
			MatrixUtil.convertTo3D(mvpMatrix, sRenderMatrix);
			RenderSupport.setBlendFactors(pma, blendMode ? blendMode : this.blendMode);
			
			context.setProgram(getProgram());
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, sRenderAlpha, 1);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 1, sRenderMatrix, true);
			context.setVertexBufferAt(0, _vertexBuffer, VertexData.POSITION_OFFSET, 
				Context3DVertexBufferFormat.FLOAT_2); 
			
			if (texture == null || tinted)
				context.setVertexBufferAt(1, _vertexBuffer, VertexData.COLOR_OFFSET, 
					Context3DVertexBufferFormat.FLOAT_4);
			
			if (texture)
			{
				context.setTextureAt(0, texture.base);
				context.setVertexBufferAt(2, _vertexBuffer, VertexData.TEXCOORD_OFFSET, 
					Context3DVertexBufferFormat.FLOAT_2);
			}
			
			context.drawTriangles(_indexBuffer);
			
			if (texture)
			{
				context.setTextureAt(0, null);
				context.setVertexBufferAt(2, null);
			}
			
			context.setVertexBufferAt(1, null);
			context.setVertexBufferAt(0, null);
		}
		
		private static function getImageProgramName(tinted:Boolean, mipMap:Boolean=true, 
													repeat:Boolean=false, format:String="bgra",
													smoothing:String="bilinear"):String
		{
			var bitField:uint = 0;
			
			if (tinted) bitField |= 1;
			if (mipMap) bitField |= 1 << 1;
			if (repeat) bitField |= 1 << 2;
			
			if (smoothing == TextureSmoothing.NONE)
				bitField |= 1 << 3;
			else if (smoothing == TextureSmoothing.TRILINEAR)
				bitField |= 1 << 4;
			
			if (format == Context3DTextureFormat.COMPRESSED)
				bitField |= 1 << 5;
			else if (format == "compressedAlpha")
				bitField |= 1 << 6;
			
			var name:String = sProgramNameCache[bitField];
			
			if (name == null)
			{
				name = PROGRAM_NAME + "_i." + bitField.toString(16);
				sProgramNameCache[bitField] = name;
			}
			
			return name;
		}
		
	}
}