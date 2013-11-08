package fish.collection.game
{
	import com.greensock.easing.Back;
	
	import fish.collection.game.poi.PoiView;
	import fish.collection.game.poi.data.PoiData;
	import fish.collection.game.util.Util;
	import fish.collection.game.view.BackgroundView;
	import fish.collection.game.view.Boid;
	import fish.collection.game.view.FishControlData;
	import fish.collection.game.view.ui.FishControlPanel;
	import fish.collection.json.ExternalConfig;
	
	import flash.display.Graphics;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import pigglife.util.Executor;
	import pigglife.util.Tween;
	
	
	
	public class GameView extends Sprite
	{
		// ポイの大きさからの差
		private const HIT_DIST_VALUE:Number = 0.5;
		private const MISS_DIST_VALUE:Number = 1.0;	
		
		private var _idelegate:GameInternalDelegate;
		private var _container:Sprite;
		
		private var _background:Sprite;
		private var _backgroundView:BackgroundView;
		
		// Poi関連
		private var _poiLayer:Sprite;
		private var _pois:Vector.<PoiView>;
		private const POI_NUM:int = 4;
		
		// Boidの数
		private const NUMBOIDS:int = 60;
		// Boidクラス
		private var _boids:Vector.<Boid>;
		
		// 魚描画レイヤー
		private var _fishLayer:Sprite;
		
		private var _fishControlPanel:FishControlPanel;
		
		// アニメーション
		private var _getMc1:Vector.<getMc1>;
		private var _missMc1:Vector.<missMc1>;
		private var _missMc2:Vector.<missMc2>;
		private var _missMc3:Vector.<missMc3>;
		private var _missMc4:Vector.<missMc4>;
		private var _waveMc_s:Vector.<waveMc_s>;
		private var _waveMc_m:Vector.<waveMc_m>;
		private var _waveMc_l:Vector.<waveMc_l>;
		
		private var _scoreData:Object = {};
		private var _gotfishData:Object = {};
		
		
		private var _scoop:Boolean;
		
		// トップに戻るためのタイムアウト関数のID
		private var timeoutID:uint;
		
		// 魚の当たり判定可視化スプライト（デバッグ用）
		private var _hitGraphic:Sprite;
		private var _boidPosGraphic:Sprite;
		private const _isHitGraphic:Boolean = false;
		
		

		public function get view():Sprite {return _container;}
		
		public function GameView()
		{
			super();
			
		}
		
		private var cnt:int = 0;
		
		/**
		 * clean
		 */
		public function clean():void
		{
			if (_container)
			{
				removeAllChild(_container);
				removeFromParent(_container);
				_container = null;
			}
			if (_fishLayer)
			{
				removeAllChild(_fishLayer);
				removeFromParent(_fishLayer);
				_fishLayer = null;
			}
			if (_fishControlPanel)
			{
				_fishControlPanel.clean();
				_fishControlPanel = null;
			}
			removeAllChild(this);
			removeFromParent(this);
		}
		
		/**
		 * 初期化
		 */
		public function initialize(idelegate:GameInternalDelegate):void
		{
			_scoop = false;
			
			// 外部コンフィグの読み込み
			if (ExternalConfig.IS_USE_EXTERNAL_JSON) 
			{
				loadJson();
			}
			else
			{
				setConfigData();
			}
			// もろもろ初期化
			_idelegate = idelegate;
			_container = new Sprite();
			addChild(_container);
			_background = new Sprite();
			_container.addChild(_background);
			_poiLayer = new Sprite();
			_container.addChild(_poiLayer);
			
			_fishLayer = new Sprite();
			_container.addChild(_fishLayer);
			
			// スライダー
			_fishControlPanel = new FishControlPanel();
			_container.addChild(_fishControlPanel);
			_fishControlPanel.visible = false;
			
			// ポイView初期化
			initPoiView();
			
			// アニメーション初期化
			initEffectAnimation();
			
			// 毎フレーム処理イベント設定
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
			
			// 当たり判定可視化
			if (_isHitGraphic)
			{
				_hitGraphic = new Sprite();
				_container.addChild(_hitGraphic);
				_boidPosGraphic = new Sprite();
				_container.addChild(_boidPosGraphic);
			}
			
			_container.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			
		}
		
		/**
		 * ステージにaddされたイベントハンドラ 
		 * @param event
		 * 
		 */		
		protected function onAddedToStage(event:Event):void
		{
			// TODO Auto-generated method stub
			_container.addEventListener(MouseEvent.CLICK, onClick);
			_container.removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			event.stopPropagation();
		}
		
		/**
		 * クリックハンドラ 
		 * @param event
		 * 
		 */		
		protected function onClick(event:MouseEvent):void
		{
			// スライダーを表示
			_fishControlPanel.visible = !_fishControlPanel.visible;
			for (var i:int = 0, len:int = _pois.length; i < len; i++)
			{
				_pois[i].rotSmooth = _fishControlPanel.visible; 
			}
		}				
		
		/**
		 * ポイを追加する 
		 * @param startData
		 * 
		 */		
		public function addPoi(startData:Object):void
		{
			// ポイデータの作成
			var data:PoiData = new PoiData(startData);
			var t_id:int = int(data.t_id) - 1;
			_pois[t_id].show(data);
			_pois[t_id].x = FishControlData.initPoiPos[t_id].x;
			_pois[t_id].y = FishControlData.initPoiPos[t_id].y;
			
			// トップに戻るタイムアウト関数のクリア
			clearTimeout(timeoutID);
		}
		
		/**
		 * 毎フレームイベントハンドラ
		 */
		public function onEnterFrame(ev:Event) : void 
		{ 
			// 毎フレーム関数
			updateBoids();
			
			// デバッグ用 updatePoiPos
			//updatePoiPos_debug();
		}
		private function onMouseUp(e:Event):void
		{
			_scoop = true;
		}
		
		/**
		 * 背景の更新 
		 * 
		 */		
		public function updateBackground():void
		{
			if (!_backgroundView)
			{
				_backgroundView = new BackgroundView();
				_background.addChild(_backgroundView);
			}
			_backgroundView.update();
		}
		
		/**
		 * 魚のカラーバリエーション更新 
		 * 
		 */		
		public function updateFishColor():void
		{
			// Boid初期設定
			var i:int;
			for (i = 0; i < NUMBOIDS; i++) 
			{
				// Boid設定
				var b:Boid = _boids[i];
				b.setFishView(_backgroundView.backId);	// ここを背景クラスのIDからとってくる
			}
		}
		
		/**
		 * ポイを動かす
		 * @param data
		 */
		public function updatePoiPos(locateData:Object):void
		{
			var t_id:int = locateData.t_id - 1;
			var i:int;
			var b:Boid;
			var hitOnce:Boolean = false;
			// もっとも近い魚との距離
			var distPoiMin:Number = 1000000000.0;
			/*-------------------------------------------
			ポイと魚の更新	
			-------------------------------------------*/
			// 救った魚の合計数
			var catchFishNum:int = 0;
			var catchBoids:Vector.<Boid> = new Vector.<Boid>();
			for (i = 0; i < NUMBOIDS; i++) 
			{  
				b = _boids[i];
				
				// 魚とポイの距離
				var boidDist:Number = b.getDist(_pois[t_id].x, _pois[t_id].y);
				
				/*-------------------------------------------
				当たり判定
				-------------------------------------------*/
				var __hit:Boolean = false;
				if (boidDist < _pois[t_id].getPoiSize() * HIT_DIST_VALUE)	// 魚とポイの距離でヒット判定
				{
					__hit = true;
					hitOnce = true;	// 一匹はヒットしてる魚がいる
					_pois[t_id].isTutorial = false;	// チュートリアル終了
				}
				
				// すくったときにヒットしてたら
				if (locateData.data.doScoop && __hit)
				{
					// 捕獲した時の処理
					catchFish(t_id, b, locateData);
					// すくった魚の数インクリメント
					catchFishNum++;
					catchBoids.push(b);
				}
				
				// 一番近い魚の距離を算出
				if (distPoiMin > boidDist)
					distPoiMin = boidDist;
			}
			// スコア表示アニメーション
			var len:int = catchBoids.length;
			var j:int = 0;
			if (len > 0)
			{
				for(i = 0; i < len; i++)
				{
					// スコア表示アニメーション
					var getMc:getMc1 = new getMc1();
					getMc.x = catchBoids[i].x;
					getMc.y = catchBoids[i].y;
					getMc.rotationZ = _pois[t_id].rotationZ;
					getMc.scaleX = getMc.scaleY = 0.5;
					getMc.score.text.text = _scoreData[catchBoids[i].fishData.type].normal + '\r';
					var rate:Number = (_pois[t_id].y - catchBoids[i].y) / (_pois[t_id].x - catchBoids[i].x);
					var zoomX:Number = getMc.x + 10;
					var zoomY:Number = getMc.y + 10 * rate;
					if (_pois[t_id].x > catchBoids[i].x)
					{
						zoomX =　getMc.x - 40;
					}
					else
					{
						zoomX =　getMc.x + 40;
					}
					if (_pois[t_id].y > catchBoids[i].y)
					{
						zoomY = getMc.y - 40;
					}
					else
					{
						zoomY = getMc.y + 40;
					}
					//Tween.applyTo(getMc, 2.0, {x: getMc.x + zoomX, y: getMc.y + zoomY, ease:Back.easeOut});
					Executor.executeAfterWithName(i*5, 'getMc' + t_id, scoreAnimation, getMc, t_id, zoomX, zoomY);
				}
			}
			
			/*-------------------------------------------
			すくった時の処理
			-------------------------------------------*/
			if (locateData.data.doScoop)
			{
				/*-------------------------------------------
				ミス処理
				-------------------------------------------*/
				if (!hitOnce && distPoiMin < _pois[t_id].getPoiSize() * MISS_DIST_VALUE && !_pois[t_id].isTutorial)	// ヒットしてなくて一番近い魚の距離が○◯未満なら かつ　チュートリアルじゃない時
				{
					// ミスした時の処理
					miss(t_id, locateData);
				}
				else
				{
					// すくうアニメーション入れる
					_pois[t_id].scoopAnimation();
				}
			}
			
			// ポイの位置更新
			_pois[t_id].updatePoiPos(
				 Number(locateData.data.acg.x) * 1.8,
				-Number(locateData.data.acg.y) * 1.8);
			
			// ポイが画面外に行かないようにする処理
			poiStopper(t_id);
			
			// 当たり判定可視化
			if (_isHitGraphic)
			{
				var g:Graphics = _hitGraphic.graphics;
				g.clear();
				g.beginFill(0xFF0000, 0.3);
				g.drawCircle(_pois[t_id].x, _pois[t_id].y, _pois[t_id].getPoiSize() * MISS_DIST_VALUE);
				g.endFill();
				g.beginFill(0x00FF00, 0.3);
				g.drawCircle(_pois[t_id].x, _pois[t_id].y, _pois[t_id].getPoiSize() * HIT_DIST_VALUE);
				g.endFill();
			}
		}
		
		/**
		 *ポイ回転初期化 
		 * @param rotData
		 * 
		 */		
		public function initPoiRot(rotData:Object = null):void
		{
			var t_id:int = rotData.t_id - 1;
			var rot:Number = rotData.data.alpha;
			_pois[t_id].initRotatePoi(rot);
		}
		/**
		 *ポイ回転
		 * @param rotData
		 * 
		 */		
		public function setPoiRot(rotData:Object = null):void
		{
			var t_id:int = rotData.t_id - 1;
//			var rot:Number = rotData.data.alpha;
			var rot:Number = rotData.data.webkitCompassHeading;
			_pois[t_id].rotatePoi(rot, rotData.data.webkitCompassAccuracy);
		}
		
		public function setRotateCorrection(correctionData:Object):void
		{
			FishControlData.paramsPoi[correctionData.t_id].ORIENTATION += correctionData.data.val;
		}
		
		/**
		 * ぽいを止める 
		 * @param data
		 * 
		 */		
		public function stopPoi(data:Object):void
		{
			var t_id:int = data.data.t_id - 1;
			// poiViewがonGame　かつ　ライフがない時 ゲームオーバー
			if (_pois[t_id].life <= 0)
				_pois[t_id].gameOverAnimation();	// ゲームオーバーアニメーション再生
			else
				_pois[t_id].resetPoi();	// 強制終了
			
			// トップ画面表示処理（待機画面）
			var onGame:Boolean = false;
			for (var i:int = 0, len:int = _pois.length; i < len; i++)
			{
				if (_pois[i].onGame)
					onGame = true;
			}
			// ゲーム中でないとき
			if (!onGame)
			{
				// トップ画面表示
				clearTimeout(timeoutID);	// 一旦クリアする
				timeoutID = setTimeout(_idelegate.showTopView, 1000);
			}
		}
		
		/**
		 *アニメーション終了ハンドラ 
		 * @param mc
		 */		
		private function onAnimationEnd(mc:MovieClip):void
		{
			removeFromParent(mc);
			mc = null;
		}
		
		/**
		 *アニメーション終了後に消去する 
		 * @param mc
		 */		
		private function onAnimationEndAndDelete(mc:MovieClip):void
		{
			removeFromParent(mc);
			mc = null;
		}
		
		/**
		 * 波紋を出す
		 * @param x : 座標
		 * @param y : 座標
		 * @param size : サイズ('small', 'medium', 'large')
		 * @return 
		 */
		public function createWave(px:Number, py:Number, size:String):void 
		{
			var wave:MovieClip;
			switch(size)
			{
				case 'small':
					wave = new waveMc_s();
					break;
				case 'medium':
					wave = new waveMc_m();
					break;
				case 'large':
					wave = new waveMc_l();
					break;
				default:
					break;
			}
			wave.x = px;
			wave.y = py;
			wave.gotoAndPlay(0);
			_container.addChild(wave);
			Executor.executeAfterWithName(wave.totalFrames, 'waveMc', onAnimationEndAndDelete, wave);
		}
		
		/**
		 * 魚の毎フレーム関数
		 */
		public function updateBoids() : void 
		{
			var b:Boid;
			var i:int;
			// 当たり判定可視化
			if (_isHitGraphic)
			{
				var g:Graphics = _boidPosGraphic.graphics;
				g.clear();
			}
			for (i = 0; i < NUMBOIDS; i++) 
			{
				b = _boids[i];  
				b.force(_boids, i, _pois);
				b.update(i);
				
				// 当たり判定可視化
				if (_isHitGraphic)
				{
					g.beginFill(0x0000FF);
					g.drawCircle(b.x, b.y, 5);
					g.endFill();
				}
			} 
		}
		
		/**
		 * boid初期化 
		 * 
		 */		
		public function initBoids():void
		{
			// Boid初期設定
			var i:int;
			_boids = new Vector.<Boid>();
			for (i = 0; i < NUMBOIDS; i++) 
			{
				// Boid設定
				var b:Boid = new Boid();
				const ph:Number = i * 2.0 * Math.PI / Number(NUMBOIDS);
				b.initialize( 
					Util.getRandom(0.0, 1600),
					Util.getRandom(0.0, 900),
					Util.getRandom(-1, 1),
					Util.getRandom(-1, 1),
					i,
					_idelegate
				);
				b.setFishCode();
				b.setFishView(_backgroundView.backId);	// ここを背景クラスのIDからとってくる
				_fishLayer.addChild(b);
				
				_boids[i] = b;
			}
		}
		//=========================================================
		// PRIVATE METHODS
		//=========================================================
		/**
		 * poiView初期化 
		 * 
		 */		
		private function initPoiView():void
		{
			// PoiView初期設定
			_pois = new Vector.<PoiView>(POI_NUM, true);			
			for (var j:int = 0, len:int = _pois.length; j < len; j++)
			{
				_pois[j] = new PoiView(_idelegate);
				_pois[j].initialize(j);
				_poiLayer.addChild(_pois[j]);
			}
		}
		
		/**
		 * エフェクトアニメーション初期化 
		 * 
		 */		
		private function initEffectAnimation():void
		{
			// アニメーション初期化
			_getMc1 = new Vector.<getMc1>(POI_NUM, true);
			_missMc1 = new Vector.<missMc1>(POI_NUM, true);
			_missMc2 = new Vector.<missMc2>(POI_NUM, true);
			_missMc3 = new Vector.<missMc3>(POI_NUM, true);
			_missMc4 = new Vector.<missMc4>(POI_NUM, true);
			for (var k:int = 0; k < POI_NUM; k++)
			{
				_getMc1[k] = new getMc1();
				_missMc1[k] = new missMc1();
				_missMc2[k] = new missMc2();
				_missMc3[k] = new missMc3();
				_missMc4[k] = new missMc4();
			}
			_waveMc_s = new Vector.<waveMc_s>();
			_waveMc_m = new Vector.<waveMc_m>();
			_waveMc_l = new Vector.<waveMc_l>();
		}
		/**
		 * JSON読み込み 
		 * @param event
		 */
		private function loadJson():void
		{
			// スコアJSON読み込み
			var scoreLoader:URLLoader = new URLLoader();
			scoreLoader.dataFormat = URLLoaderDataFormat.TEXT;
			scoreLoader.addEventListener(Event.COMPLETE, onLoadScore);
			scoreLoader.load(new URLRequest("fish/collection/json/scorelist.json"));
			
			// 成功時送信JSON読み込み
			var sendfishLoader:URLLoader = new URLLoader();
			sendfishLoader.dataFormat = URLLoaderDataFormat.TEXT;
			sendfishLoader.addEventListener(Event.COMPLETE, onLoadSendfish);
			sendfishLoader.load(new URLRequest("fish/collection/json/sendfish.json"));
		}
		
		/**
		 * 外部コンフィグデータを設定 
		 * 
		 */		
		private function setConfigData():void
		{
			// スコアデータを設定
			_scoreData = ExternalConfig.scorelist;
			// 成功時送信データ設定
			_gotfishData = ExternalConfig.sendfish;
		}
		
		/**
		 * スコアデータJSON読み込み完了 
		 * @param event
		 */
		private function onLoadScore(event:Event):void
		{
			var json:String = URLLoader(event.currentTarget).data;
			var data:Object = {};
			data = JSON.parse(json);
			if (data.type6)
				_scoreData = data;
			else
				Error.throwError(Object, 0, data);
		}
		
		/**
		 * 成功時送信データ読み込み完了 
		 * @param event
		 */
		private function onLoadSendfish(event:Event):void
		{
			var json:String = URLLoader(event.currentTarget).data;
			var data:Object = {};
			data = JSON.parse(json);
			// 不正なデータ型ならエラーが出るようにする
			if (data.data.fishInfo)
				_gotfishData = JSON.parse(json);
			else
				Error.throwError(Object, 0, data);
		}
		
		/**
		 * // ポイが画面外に出ないようにストップさせる
		 * @param t_id
		 * 
		 */		
		private function poiStopper(t_id:int):void
		{
			// ポイが画面外に出ないようにストップさせる
			if (_pois[t_id].x > _container.stage.stageWidth)
			{
				_pois[t_id].x = _container.stage.stageWidth;
			}
			else if (_pois[t_id].x < 0.0)
			{
				_pois[t_id].x = 0.0;
			}
			if (_pois[t_id].y > _container.stage.stageHeight)
			{
				_pois[t_id].y = _container.stage.stageHeight;
			}
			else if (_pois[t_id].y < 0.0)
			{
				_pois[t_id].y = 0.0;
			}
		}
		
		/**
		 * 
		 * 
		 */		
		private function updatePoiPos_debug():void
		{
			
			/*-------------------------------------------
			ここはデバッグ用
			-------------------------------------------*/
			_container.mouseChildren = true;
			_container.mouseEnabled = true;
			_container.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);

			var obj:Object = {
				data : {
					t_id : 1,
					doScoop : _scoop,
					acg: {
						x : _container.mouseX,
						y : _container.mouseY
//						x : Util.map(_container.mouseX, 0.0, 800.0, -5.0, 5.0),
//						y : -Util.map(_container.mouseY, 0.0, 800.0, -5.0, 5.0)
					}
				}
			};
			
			if (_pois[obj.data.t_id-1].life <= 0)
				stopPoi(obj);
			else
				updatePoiPos(obj);
			_scoop = false; 
			/*-------------------------------------------
			ここまでデバッグ用コード
			GameModelのupdatePoiPosをコメント解除するの忘れないように
			-------------------------------------------*/
		}
		
		/**
		 * 捕獲した時の処理 
		 * @param t_id
		 * @param b
		 * @param locateData
		 * 
		 */		
		private function catchFish(t_id:int, b:Boid, locateData:Object):void
		{
			if (!b.isCatched)	// 捕獲フラグOFFの時
			{
				// 魚の捕獲アニメーション
				b.catchedAnimation();
				// 成功時
				_gotfishData.data.t_id = locateData.t_id ;
				_gotfishData.data.fishInfo.size = "normal";
				var splits:Array = b.fishData.type.split('ype');
				//_gotfishData.data.fishInfo.type = b.fishData.type;
				_gotfishData.data.fishInfo.type = splits[1];
				_gotfishData.data.fishInfo.score = _scoreData[b.fishData.type][_gotfishData.data.fishInfo.size];
				_idelegate.sendFish(_gotfishData);
				
				// ピチャピチャアニメ
				var waveGetMc:waveMc_get = new waveMc_get();
				waveGetMc.x = b.x;
				waveGetMc.y = b.y;
				_container.addChild(waveGetMc);
				Executor.executeAfterWithName(waveGetMc.totalFrames, 'waveMc_get' + t_id, onAnimationEnd, waveGetMc);
			}
		}
		
		private function scoreAnimation(mc:MovieClip, tid:int, zoomX:Number, zoomY:Number):void
		{
			_container.addChild(mc);
			mc.gotoAndPlay(0);
			Tween.applyTo(mc, 2.0, {x: zoomX, y: zoomY/*, ease:Back.easeOut*/});
			Tween.applyFromTo(mc, 1.0, {x: mc.x, y: mc.y}, {x: zoomX, y: zoomY});
			Executor.executeAfterWithName( mc.totalFrames, 'getMc' + tid, onAnimationEnd, mc);
		}
		/**
		 * ミスした時の処理 
		 * @param t_id
		 * @param locateData
		 * 
		 */		
		private function miss(t_id:int, locateData:Object):void
		{
			// 失敗時
			_pois[t_id].life--;
			_pois[t_id].updateLife();
			if (_pois[t_id].life > 0)
			{
				// ポイの失敗アニメーション
				_pois[t_id].missAnimation();
				// 失敗アニメーション
				var missMc:missMc3 = new missMc3();
				missMc.x = _pois[t_id].x;
				missMc.y = _pois[t_id].y;
				missMc.rotationZ = _pois[t_id].rotationZ;
				_container.addChild(missMc);
				missMc.gotoAndPlay(0);
				Executor.executeAfterWithName( missMc.totalFrames, '_missMc3', onAnimationEnd, missMc);
			}
			else
			{
				// ゲームオーバーアニメーション
				var gameOverMc:gameOver = new gameOver();
				gameOverMc.x = _pois[t_id].x;
				gameOverMc.y = _pois[t_id].y;
				gameOverMc.rotationZ = _pois[t_id].rotationZ;
				_container.addChild(gameOverMc);
				gameOverMc.gotoAndPlay(0);
				Executor.executeAfterWithName( gameOverMc.totalFrames, 'gameOverMc', onAnimationEnd, gameOverMc);
			}
			// ポイのライフ情報送信
			if (_pois[t_id].life > -1)
			{
				_idelegate.sendLife({id:"game.life", data:{t_id:locateData.t_id , lastLife:_pois[t_id].life}});
			}
		}
	}
}