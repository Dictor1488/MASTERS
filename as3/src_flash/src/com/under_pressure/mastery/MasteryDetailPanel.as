package com.under_pressure.mastery
{
    import flash.display.GradientType;
    import flash.display.Graphics;
    import flash.display.Shape;
    import flash.display.Sprite;
    import flash.events.MouseEvent;
    import flash.filters.DropShadowFilter;
    import flash.filters.GlowFilter;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;

    public class MasteryDetailPanel extends Sprite
    {
        private static const W:int = 720;
        private static const H:int = 470;

        private static const PAD:int = 18;

        private static const HEADER_H:int       = 56;
        private static const PROGRESS_H:int     = 6;
        private static const PROGRESS_TOP_GAP:int = 30;
        private static const PROGRESS_BOTTOM_GAP:int = 22;

        private static const BLOCK_ROW_H:int    = 80;
        private static const GRAPH_H:int        = 180;
        private static const GRAPH_LEFT_AXIS:int = 38;

        private static const BG_COLOR_TOP:uint   = 0x1F2429;
        private static const BG_COLOR_BOT:uint   = 0x12161A;
        private static const BG_ALPHA:Number     = 0.96;
        private static const OVERLAY_COLOR:uint  = 0x000000;
        private static const OVERLAY_ALPHA:Number = 0.55;
        private static const BORDER_COLOR:uint   = 0xC8B97A;
        private static const BORDER_ALPHA:Number = 0.55;

        private static const COLOR_TEXT:uint     = 0xE8E8E8;
        private static const COLOR_DIM:uint      = 0x8896A2;
        private static const COLOR_LABEL:uint    = 0xA8B2BC;
        private static const COLOR_GRID:uint     = 0x7A8490;
        private static const COLOR_LINE:uint     = 0xF1F1F1;
        private static const COLOR_PROGRESS:uint = 0x7CB342;
        private static const COLOR_PROGRESS_BG:uint = 0x2A2F35;
        private static const COLOR_DELTA_UP:uint   = 0x7CB342;
        private static const COLOR_DELTA_DOWN:uint = 0xE24B4A;
        private static const COLOR_DELTA_FLAT:uint = 0x8896A2;
        private static const COLOR_RECORD_BG:uint  = 0x244A1B;   
        private static const COLOR_RECORD_TEXT:uint = 0x9FE57A;

        private static const FONT_FACE:String     = "$FieldFont";
        private static const FONT_TITLE:int       = 22;
        private static const FONT_PERCENT_BIG:int = 26;
        private static const FONT_HEADER_LABEL:int = 11;
        private static const FONT_VALUE:int       = 14;
        private static const FONT_DELTA:int       = 13;
        private static const FONT_AXIS:int        = 11;
        private static const FONT_BATTLE_NUM:int  = 12;
        private static const FONT_RECORD:int      = 10;

        private var _disposed:Boolean = false;

        private var _overlay:Sprite;
        private var _root:Sprite;
        private var _bg:Shape;
        private var _graphLayer:Shape;
        private var _progressLayer:Shape;
        private var _progressTickLabels:Array;
        private var _closeBtn:Sprite;

        private var _tankNameTf:TextField;
        private var _percentBigTf:TextField;
        private var _starsShape:Shape;
        private var _flagBg:Shape;

        private var _lbTitleTf:TextField;
        private var _lbBattleTf:TextField;
        private var _lbDmgTf:TextField;
        private var _lbDeltaTf:TextField;

        private var _bbTitleTf:TextField;
        private var _bbBattleTf:TextField;
        private var _bbDmgTf:TextField;
        private var _bbDeltaTf:TextField;
        private var _bbRecordPill:Shape;
        private var _bbRecordTf:TextField;

        private var _dynTitleTf:TextField;
        private var _dyn10LblTf:TextField;
        private var _dyn10ValTf:TextField;
        private var _dyn25LblTf:TextField;
        private var _dyn25ValTf:TextField;

        private var _listTf:Array;

        private var _axisLabels:Array;
        private var _xAxisLabels:Array;
        private var _markLabel:TextField;
        private var _yAxisUnitTf:TextField;
        private var _xAxisUnitTf:TextField;
        private var _battleListTitleTf:TextField;

        private var _matrix:Matrix;
        private var _textShadow:DropShadowFilter;

        private var _str:Object = {
            lastBattle:  "Last battle",
            bestBattle:  "Best battle",
            dynamics:    "Battle dynamics",
            record:      "RECORD",
            last10:      "Last 10",
            last25:      "Last 25",
            progress:    "Marks progress",
            battles:     "Battles",
            noData:      "N/A"
        };

        private var _tankName:String   = "";
        private var _flag:String       = "";
        private var _stars:int         = 0;
        private var _currentMark:Number = NaN;
        private var _history:Array     = [];
        private var _bestIdx:int       = -1;

        public function MasteryDetailPanel()
        {
            super();
            _matrix     = new Matrix();
            _textShadow = new DropShadowFilter(1, 45, 0x000000, 0.85, 2, 2, 1.2, 1);

            _overlay = new Sprite();
            // FIX: починаємо з mouseEnabled=false — вмикаємо тільки в show()
            _overlay.mouseEnabled = false;
            addChild(_overlay);
            _overlay.addEventListener(MouseEvent.CLICK, _onOverlayClick);

            _root = new Sprite();
            _root.mouseEnabled  = true;
            _root.mouseChildren = true;
            addChild(_root);

            _bg = new Shape();
            _bg.filters = [new GlowFilter(0x000000, 0.6, 12, 12, 1, 1)];
            _root.addChild(_bg);

            _progressLayer = new Shape();
            _root.addChild(_progressLayer);

            _progressTickLabels = [];
            for (var pti:int = 0; pti < 11; pti++)
            {
                var ttf:TextField = _mkText(9, COLOR_LABEL, TextFieldAutoSize.CENTER);
                _progressTickLabels.push(ttf);
            }

            _graphLayer = new Shape();
            _root.addChild(_graphLayer);

            _starsShape   = new Shape();
            _root.addChild(_starsShape);
            _flagBg       = new Shape();
            _root.addChild(_flagBg);
            _tankNameTf   = _mkText(FONT_TITLE,     COLOR_TEXT,  TextFieldAutoSize.LEFT);
            _percentBigTf = _mkText(FONT_PERCENT_BIG, COLOR_TEXT, TextFieldAutoSize.RIGHT);

            _lbTitleTf    = _mkText(FONT_HEADER_LABEL, COLOR_LABEL, TextFieldAutoSize.LEFT);
            _lbBattleTf   = _mkText(FONT_VALUE,        COLOR_TEXT,  TextFieldAutoSize.LEFT);
            _lbDmgTf      = _mkText(FONT_VALUE,        COLOR_TEXT,  TextFieldAutoSize.LEFT);
            _lbDeltaTf    = _mkText(FONT_DELTA,        COLOR_DELTA_FLAT, TextFieldAutoSize.LEFT);

            _bbTitleTf    = _mkText(FONT_HEADER_LABEL, COLOR_LABEL, TextFieldAutoSize.LEFT);
            _bbBattleTf   = _mkText(FONT_VALUE,        COLOR_TEXT,  TextFieldAutoSize.LEFT);
            _bbDmgTf      = _mkText(FONT_VALUE,        COLOR_TEXT,  TextFieldAutoSize.LEFT);
            _bbDeltaTf    = _mkText(FONT_DELTA,        COLOR_DELTA_UP,  TextFieldAutoSize.LEFT);
            _bbRecordPill = new Shape();
            _root.addChild(_bbRecordPill);
            _bbRecordTf   = _mkText(FONT_RECORD, COLOR_RECORD_TEXT, TextFieldAutoSize.LEFT);

            _dynTitleTf   = _mkText(FONT_HEADER_LABEL, COLOR_LABEL, TextFieldAutoSize.LEFT);
            _dyn10LblTf   = _mkText(FONT_DELTA,        COLOR_DIM,   TextFieldAutoSize.LEFT);
            _dyn10ValTf   = _mkText(FONT_VALUE,        COLOR_TEXT,  TextFieldAutoSize.LEFT);
            _dyn25LblTf   = _mkText(FONT_DELTA,        COLOR_DIM,   TextFieldAutoSize.LEFT);
            _dyn25ValTf   = _mkText(FONT_VALUE,        COLOR_TEXT,  TextFieldAutoSize.LEFT);

            _listTf = [];
            for (var i:int = 0; i < 3; i++)
            {
                _listTf.push({
                    num:   _mkText(FONT_BATTLE_NUM, COLOR_TEXT, TextFieldAutoSize.LEFT),
                    dmg:   _mkText(FONT_BATTLE_NUM, COLOR_TEXT, TextFieldAutoSize.LEFT),
                    delta: _mkText(FONT_BATTLE_NUM, COLOR_DELTA_FLAT, TextFieldAutoSize.LEFT)
                });
            }

            _axisLabels  = [];
            _xAxisLabels = [];
            for (i = 0; i < 6; i++)
                _axisLabels.push(_mkText(FONT_AXIS, COLOR_LABEL, TextFieldAutoSize.RIGHT));
            for (i = 0; i < 4; i++)
                _xAxisLabels.push(_mkText(FONT_AXIS, COLOR_LABEL, TextFieldAutoSize.CENTER));

            _markLabel = _mkText(11, 0xFFFFFF, TextFieldAutoSize.LEFT);
            _yAxisUnitTf       = _mkText(FONT_AXIS, COLOR_LABEL, TextFieldAutoSize.LEFT);
            _xAxisUnitTf       = _mkText(FONT_AXIS, COLOR_LABEL, TextFieldAutoSize.LEFT);
            _battleListTitleTf = _mkText(FONT_HEADER_LABEL, COLOR_LABEL, TextFieldAutoSize.LEFT);

            _closeBtn = new Sprite();
            _closeBtn.buttonMode    = true;
            _closeBtn.useHandCursor = true;
            _closeBtn.mouseChildren = false;
            _closeBtn.addEventListener(MouseEvent.CLICK, _onCloseClick);
            _closeBtn.addEventListener(MouseEvent.ROLL_OVER, _onCloseRollOver);
            _closeBtn.addEventListener(MouseEvent.ROLL_OUT,  _onCloseRollOut);
            _root.addChild(_closeBtn);
            _drawCloseBtn(false);

            visible = false;
        }
        public function setLocalization(data:Object):void
        {
            if (_disposed || data == null) return;
            for (var k:String in data)
                _str[k] = String(data[k]);
        }

        public function setTankInfo(tankName:String, flagText:String, stars:int, currentMark:Number):void
        {
            if (_disposed) return;
            _tankName    = tankName != null ? tankName : "";
            _flag        = flagText != null ? flagText : "";
            _stars       = stars;
            _currentMark = currentMark;
        }

        public function setBattles(entries:Array):void
        {
            if (_disposed) return;
            _history = (entries != null) ? entries.concat() : [];
            _bestIdx = _findBestIdx();
        }

        public function show():void
        {
            if (_disposed) return;
            _overlay.mouseEnabled = true;  // активуємо перехоплення кліків тільки при показі
            visible = true;
            _layout();
        }

        public function hide():void
        {
            if (_disposed) return;
            visible = false;
            // FIX: вимикаємо mouseEnabled коли панель прихована.
            // Без цього overlay перехоплював всі кліки в гаражі навіть коли detail закритий.
            _overlay.mouseEnabled = false;
        }

        public function updateLayout():void
        {
            if (_disposed) return;
            _layout();
        }

        public function dispose():void
        {
            if (_disposed) return;
            _disposed = true;
            try { _overlay.removeEventListener(MouseEvent.CLICK, _onOverlayClick); } catch (e:Error) {}
            try
            {
                _closeBtn.removeEventListener(MouseEvent.CLICK, _onCloseClick);
                _closeBtn.removeEventListener(MouseEvent.ROLL_OVER, _onCloseRollOver);
                _closeBtn.removeEventListener(MouseEvent.ROLL_OUT,  _onCloseRollOut);
            }
            catch (e:Error) {}
        }


        private function _layout():void
        {
            if (_disposed || !visible) return;

            // FIX: overlay має покривати весь екран через stage координати,
            // але _overlay є дочірнім до this (Injector).
            // Якщо this.x/y != 0 — overlay зміщується. Компенсуємо через this позицію.
            var sw:int = (stage != null) ? stage.stageWidth  : 1920;
            var sh:int = (stage != null) ? stage.stageHeight : 1080;
            _overlay.graphics.clear();
            _overlay.graphics.beginFill(OVERLAY_COLOR, OVERLAY_ALPHA);
            // Рахуємо offset відносно батька (this = Injector)
            var ox:Number = (parent != null) ? -parent.x : 0;
            var oy:Number = (parent != null) ? -parent.y : 0;
            _overlay.x = ox;
            _overlay.y = oy;
            _overlay.graphics.drawRect(0, 0, sw, sh);
            _overlay.graphics.endFill();

            // Center root
            _root.x = int((sw - W) * 0.5);
            _root.y = int((sh - H) * 0.5);

            _drawBackground();
            _drawCloseBtn(false);
            _layoutHeader();
            _drawProgressBar();
            _layoutStatBlocks();
            _layoutBattleList();
            _layoutGraph();
        }

        private function _drawBackground():void
        {
            var g:Graphics = _bg.graphics;
            g.clear();
            _matrix.createGradientBox(W, H, Math.PI / 2, 0, 0);
            g.beginGradientFill(GradientType.LINEAR,
                [BG_COLOR_TOP, BG_COLOR_BOT],
                [BG_ALPHA,     BG_ALPHA],
                [0, 255], _matrix);
            g.lineStyle(1, BORDER_COLOR, BORDER_ALPHA);
            g.drawRoundRect(0, 0, W, H, 6, 6);
            g.endFill();
            g.lineStyle(NaN);
        }

        private function _drawCloseBtn(hover:Boolean):void
        {
            var size:int = 22;
            var pad:int  = 12;
            _closeBtn.x = W - size - pad;
            _closeBtn.y = pad;
            var g:Graphics = _closeBtn.graphics;
            g.clear();
            g.beginFill(0x000000, 0.001);
            g.drawRect(0, 0, size, size);
            g.endFill();
            if (hover)
            {
                g.beginFill(0xFFFFFF, 0.10);
                g.drawRoundRect(0, 0, size, size, 4, 4);
                g.endFill();
            }
            var pad2:Number = 6;
            g.lineStyle(1.6, 0xCCCCCC, hover ? 1.0 : 0.7, true);
            g.moveTo(pad2,        pad2);
            g.lineTo(size - pad2, size - pad2);
            g.moveTo(size - pad2, pad2);
            g.lineTo(pad2,        size - pad2);
            g.lineStyle(NaN);
        }

        private function _onCloseClick(e:MouseEvent):void
        {
            e.stopImmediatePropagation();
            dispatchEvent(new MasteryPanelEvent(MasteryPanelEvent.EXPAND_TOGGLE, null));
        }
        private function _onCloseRollOver(e:MouseEvent):void { _drawCloseBtn(true); }
        private function _onCloseRollOut(e:MouseEvent):void  { _drawCloseBtn(false); }

        private function _onOverlayClick(e:MouseEvent):void
        {
            dispatchEvent(new MasteryPanelEvent(MasteryPanelEvent.EXPAND_TOGGLE, null));
        }

        private function _layoutHeader():void
        {
            var headerY:int = PAD + 6;
            var centerX:int = int(W * 0.5);
            _drawStars(_starsShape.graphics, PAD + 4, headerY + 6, _stars);
            _tankNameTf.htmlText = _fmt(_safeStr(_tankName, "-"), FONT_TITLE, COLOR_TEXT);
            var nameW:Number = _tankNameTf.width;

            var flagW:Number   = 0;
            var flagH:Number   = 0;
            var flagGap:Number = 0;
            var hasFlag:Boolean = (_flag != null && _flag.length > 0);
            if (hasFlag)
            {
                flagW   = 28;
                flagH   = 18;
                flagGap = 10;
            }

            var groupW:Number = flagW + flagGap + nameW;
            var groupX:Number = centerX - groupW * 0.5;

            _flagBg.graphics.clear();
            if (hasFlag)
                _drawFlag(_flagBg.graphics, _flag, groupX, headerY + 4, flagW, flagH);

            _tankNameTf.x = int(groupX + flagW + flagGap);
            _tankNameTf.y = headerY;

            var pctStr:String = _fmtPercent(_currentMark, "-");
            _percentBigTf.htmlText = _fmt(pctStr, FONT_PERCENT_BIG, COLOR_TEXT);
            _percentBigTf.x = W - PAD - 36 - _percentBigTf.width;
            _percentBigTf.y = headerY - 2;
        }

        private function _drawStars(g:Graphics, x:Number, y:Number, filled:int):void
        {
            g.clear();
            var size:Number    = 14;
            var gap:Number     = 6;
            var goldFill:uint  = 0xE6C766;
            var dimColor:uint  = 0x4A5158;
            for (var i:int = 0; i < 3; i++)
            {
                var cx:Number = x + size * 0.5 + i * (size + gap);
                var cy:Number = y + size * 0.5;
                if (i < filled)
                {
                    g.lineStyle(NaN);
                    g.beginFill(goldFill, 1.0);
                    _starPath(g, cx, cy, size * 0.5, size * 0.22);
                    g.endFill();
                }
                else
                {
                    g.lineStyle(1.2, dimColor, 1.0, true);
                    g.beginFill(0x000000, 0);
                    _starPath(g, cx, cy, size * 0.5, size * 0.22);
                    g.endFill();
                    g.lineStyle(NaN);
                }
            }
        }

        private static function _starPath(g:Graphics, cx:Number, cy:Number,
                                          rOuter:Number, rInner:Number):void
        {
            var pts:int = 5;
            var startA:Number = -Math.PI * 0.5;
            var step:Number   = Math.PI / pts;
            for (var i:int = 0; i < pts * 2; i++)
            {
                var r:Number = (i % 2 == 0) ? rOuter : rInner;
                var a:Number = startA + i * step;
                var px:Number = cx + Math.cos(a) * r;
                var py:Number = cy + Math.sin(a) * r;
                if (i == 0) g.moveTo(px, py);
                else        g.lineTo(px, py);
            }
            g.lineTo(cx + Math.cos(startA) * rOuter, cy + Math.sin(startA) * rOuter);
        }

        private function _drawFlag(g:Graphics, tag:String, x:Number, y:Number, w:Number, h:Number):void
        {
            var t:String = (tag != null) ? tag.toUpperCase() : "";

            switch (t)
            {
                case "UK":
                    g.beginFill(0x012169, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    g.beginFill(0xC8102E, 1.0); g.drawRect(x, y + h * 0.4, w, h * 0.2); g.endFill();
                    g.beginFill(0xC8102E, 1.0); g.drawRect(x + w * 0.4, y, w * 0.2, h); g.endFill();
                    break;
                case "US":
                    g.beginFill(0xB22234, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x, y + h * 0.15, w, h * 0.10); g.endFill();
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x, y + h * 0.40, w, h * 0.10); g.endFill();
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x, y + h * 0.65, w, h * 0.10); g.endFill();
                    g.beginFill(0x3C3B6E, 1.0); g.drawRect(x, y, w * 0.4, h * 0.55); g.endFill();
                    break;
                case "DE":
                    g.beginFill(0x000000, 1.0); g.drawRect(x, y,            w, h / 3); g.endFill();
                    g.beginFill(0xDD0000, 1.0); g.drawRect(x, y + h / 3,    w, h / 3); g.endFill();
                    g.beginFill(0xFFCE00, 1.0); g.drawRect(x, y + h * 2/3, w, h / 3); g.endFill();
                    break;
                case "SU":
                    g.beginFill(0xCC0000, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    g.beginFill(0xFFD700, 1.0); g.drawRect(x + 3, y + 3, 6, 6); g.endFill();
                    break;
                case "FR":
                    g.beginFill(0x002395, 1.0); g.drawRect(x,             y, w / 3, h); g.endFill();
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x + w / 3,     y, w / 3, h); g.endFill();
                    g.beginFill(0xED2939, 1.0); g.drawRect(x + w * 2/3,  y, w / 3, h); g.endFill();
                    break;
                case "IT":
                    g.beginFill(0x009246, 1.0); g.drawRect(x,             y, w / 3, h); g.endFill();
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x + w / 3,     y, w / 3, h); g.endFill();
                    g.beginFill(0xCE2B37, 1.0); g.drawRect(x + w * 2/3,  y, w / 3, h); g.endFill();
                    break;
                case "JP":
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    g.beginFill(0xBC002D, 1.0); g.drawCircle(x + w * 0.5, y + h * 0.5, h * 0.32); g.endFill();
                    break;
                case "CN":
                    g.beginFill(0xDE2910, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    g.beginFill(0xFFDE00, 1.0); g.drawCircle(x + w * 0.25, y + h * 0.35, h * 0.13); g.endFill();
                    break;
                case "CZ":
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x, y,         w, h / 2); g.endFill();
                    g.beginFill(0xD7141A, 1.0); g.drawRect(x, y + h / 2, w, h / 2); g.endFill();
                    g.beginFill(0x11457E, 1.0);
                    g.moveTo(x,              y);
                    g.lineTo(x + w * 0.45,   y + h * 0.5);
                    g.lineTo(x,              y + h);
                    g.lineTo(x,              y);
                    g.endFill();
                    break;
                case "SE":
                    g.beginFill(0x006AA7, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    g.beginFill(0xFECC00, 1.0); g.drawRect(x,             y + h * 0.42, w,            h * 0.16); g.endFill();
                    g.beginFill(0xFECC00, 1.0); g.drawRect(x + w * 0.30,  y,            w * 0.14, h); g.endFill();
                    break;
                case "PL":
                    g.beginFill(0xFFFFFF, 1.0); g.drawRect(x, y,         w, h / 2); g.endFill();
                    g.beginFill(0xDC143C, 1.0); g.drawRect(x, y + h / 2, w, h / 2); g.endFill();
                    break;
                default:
                    g.beginFill(0x2A2F35, 1.0); g.drawRect(x, y, w, h); g.endFill();
                    break;
            }
            g.lineStyle(0.5, 0x000000, 0.6);
            g.drawRect(x + 0.5, y + 0.5, w - 1, h - 1);
            g.lineStyle(NaN);
        }

        private function _drawProgressBar():void
        {
            var g:Graphics = _progressLayer.graphics;
            g.clear();

            var top:int  = PAD + HEADER_H + PROGRESS_TOP_GAP;
            var left:int = PAD + 8;
            var right:int = W - PAD - 8;
            var width:int = right - left;

            var pct:Number = isNaN(_currentMark) ? 0 : Math.max(0, Math.min(100, _currentMark));
            var fillW:Number = width * pct / 100;

            g.beginFill(COLOR_PROGRESS_BG, 1.0);
            g.drawRect(left, top, width, PROGRESS_H);
            g.endFill();

            if (fillW < width)
            {
                var hatchLeft:Number = left + fillW;
                var hatchTop:Number  = top;
                var hatchW:Number    = (left + width) - hatchLeft;
                var hatchH:Number    = PROGRESS_H;
                g.lineStyle(0.5, 0x4A5158, 0.75);
                var stripeStep:Number = 4;
                var kStart:Number = (hatchLeft - (hatchTop + hatchH));
                var kEnd:Number   = (hatchLeft + hatchW) - hatchTop;
                var k:Number = Math.floor(kStart / stripeStep) * stripeStep;
                while (k <= kEnd)
                {
                    var yA:Number = hatchTop;
                    var xA:Number = yA + k;
                    if (xA < hatchLeft) { xA = hatchLeft; yA = xA - k; }
                    if (xA > hatchLeft + hatchW) { xA = hatchLeft + hatchW; yA = xA - k; }

                    var yB:Number = hatchTop + hatchH;
                    var xB:Number = yB + k;
                    if (xB < hatchLeft) { xB = hatchLeft; yB = xB - k; }
                    if (xB > hatchLeft + hatchW) { xB = hatchLeft + hatchW; yB = xB - k; }

                    if (yA >= hatchTop && yA <= hatchTop + hatchH &&
                        yB >= hatchTop && yB <= hatchTop + hatchH &&
                        xA >= hatchLeft && xA <= hatchLeft + hatchW &&
                        xB >= hatchLeft && xB <= hatchLeft + hatchW)
                    {
                        g.moveTo(xA, yA);
                        g.lineTo(xB, yB);
                    }
                    k += stripeStep;
                }
                g.lineStyle(NaN);
            }

            if (fillW > 0)
            {
                g.beginFill(COLOR_PROGRESS, 0.95);
                g.drawRect(left, top, fillW, PROGRESS_H);
                g.endFill();
            }

            if (fillW > 0 && fillW < width)
            {
                var markerX:Number = left + fillW;
                var markerY:Number = top + PROGRESS_H * 0.5;
                g.lineStyle(1, 0xFFFFFF, 0.85);
                g.beginFill(COLOR_PROGRESS, 1.0);
                g.drawCircle(markerX, markerY, 4);
                g.endFill();
                g.lineStyle(NaN);
            }

            for (var i:int = 0; i <= 10; i++)
            {
                var tf:TextField = _progressTickLabels[i] as TextField;
                tf.htmlText = _fmt(String(i * 10), 9, COLOR_DIM);
                var tx:Number = left + width * i / 10;
                tf.x = tx - tf.width * 0.5;
                tf.y = top - tf.height - 1;
                tf.visible = true;
            }
        }

        private function _layoutStatBlocks():void
        {
            var top:int  = PAD + HEADER_H + PROGRESS_TOP_GAP + PROGRESS_H + PROGRESS_BOTTOM_GAP;

            var colGap:int = 24;
            var totalW:int = W - PAD * 2;
            var blockW:int = int((totalW - colGap * 2) / 3);

            var col1X:int = PAD;
            var col2X:int = PAD + blockW + colGap;
            var col3X:int = PAD + (blockW + colGap) * 2;

            _lbTitleTf.htmlText = _fmt(_str.lastBattle, FONT_HEADER_LABEL, COLOR_LABEL);
            _lbTitleTf.x = col1X;
            _lbTitleTf.y = top;

            var last:Object = _history.length > 0 ? _history[_history.length - 1] : null;
            _setBattleRow(last, _lbBattleTf, _lbDmgTf, _lbDeltaTf, col1X, top + 18);

            _bbTitleTf.htmlText = _fmt(_str.bestBattle, FONT_HEADER_LABEL, COLOR_LABEL);
            _bbTitleTf.x = col2X;
            _bbTitleTf.y = top;

            var best:Object = (_bestIdx >= 0 && _bestIdx < _history.length) ? _history[_bestIdx] : null;
            _setBattleRow(best, _bbBattleTf, _bbDmgTf, _bbDeltaTf, col2X, top + 18);

            _bbRecordPill.graphics.clear();
            _bbRecordTf.visible = false;
            if (best != null && Number(best.delta) > 0)
            {
                _bbRecordTf.htmlText = _fmt(_str.record, FONT_RECORD, COLOR_RECORD_TEXT);
                var pillTextW:Number = _bbRecordTf.width;
                var pillW:Number = pillTextW + 14;
                var pillH:Number = 16;
                var pillX:Number = col2X;
                var pillY:Number = top + 18 + 22;

                _bbRecordPill.graphics.beginFill(COLOR_RECORD_BG, 0.95);
                _bbRecordPill.graphics.lineStyle(0.5, COLOR_RECORD_TEXT, 0.5);
                _bbRecordPill.graphics.drawRoundRect(pillX, pillY, pillW, pillH, pillH, pillH);
                _bbRecordPill.graphics.endFill();
                _bbRecordPill.graphics.lineStyle(NaN);
                _bbRecordTf.x = pillX + (pillW - pillTextW) * 0.5;
                _bbRecordTf.y = pillY + 1;
                _bbRecordTf.visible = true;
            }

            _dynTitleTf.htmlText = _fmt(_str.dynamics, FONT_HEADER_LABEL, COLOR_LABEL);
            _dynTitleTf.x = col3X;
            _dynTitleTf.y = top;

            var avg10:Number = _avgDelta(10);
            var avg25:Number = _avgDelta(25);

            _dyn10LblTf.htmlText = _fmt(_str.last10, FONT_DELTA, COLOR_DIM);
            _dyn10LblTf.x = col3X;
            _dyn10LblTf.y = top + 18;

            _dyn10ValTf.htmlText = _fmtDeltaHTML(avg10);
            _dyn10ValTf.x = col3X + 70;
            _dyn10ValTf.y = top + 18;

            _dyn25LblTf.htmlText = _fmt(_str.last25, FONT_DELTA, COLOR_DIM);
            _dyn25LblTf.x = col3X;
            _dyn25LblTf.y = top + 18 + 20;

            _dyn25ValTf.htmlText = _fmtDeltaHTML(avg25);
            _dyn25ValTf.x = col3X + 70;
            _dyn25ValTf.y = top + 18 + 20;
        }

        private function _setBattleRow(entry:Object, numTf:TextField, dmgTf:TextField,
                                        deltaTf:TextField, x:int, y:int):void
        {
            if (entry == null)
            {
                numTf.htmlText   = _fmt("-", FONT_VALUE, COLOR_DIM);
                dmgTf.htmlText   = _fmt("-", FONT_VALUE, COLOR_DIM);
                deltaTf.htmlText = _fmt("-", FONT_DELTA, COLOR_DIM);
            }
            else
            {
                var num:int = int(entry.num);
                var dmg:int = int(entry.dmg);
                var delta:Number = Number(entry.delta);
                numTf.htmlText   = _fmt(String(num), FONT_VALUE, COLOR_TEXT);
                dmgTf.htmlText   = _fmt((dmg > 0 ? _fmtNum(dmg) : "-"),
                                        FONT_VALUE, dmg > 0 ? COLOR_TEXT : COLOR_DIM);
                deltaTf.htmlText = _fmtDeltaHTML(delta);
            }
            numTf.x   = x;
            numTf.y   = y;
            dmgTf.x   = x + 50;
            dmgTf.y   = y;
            deltaTf.x = x + 130;
            deltaTf.y = y;
        }

        private function _layoutBattleList():void
        {
            var listX:int = PAD;
            var listY:int = PAD + HEADER_H + PROGRESS_TOP_GAP + PROGRESS_H + PROGRESS_BOTTOM_GAP + BLOCK_ROW_H + 12;

            _battleListTitleTf.htmlText = _fmt(_str.battles, FONT_HEADER_LABEL, COLOR_LABEL);
            _battleListTitleTf.x = listX;
            _battleListTitleTf.y = listY;
            _battleListTitleTf.visible = true;
            listY += 18;

            var n:int = Math.min(3, _history.length);
            for (var row:int = 0; row < 3; row++)
            {
                var item:Object = _listTf[row];
                var rowY:int = listY + row * 22;
                if (row < n)
                {
                    var entry:Object = _history[_history.length - 1 - row];
                    var num:int   = int(entry.num);
                    var dmg:int   = int(entry.dmg);
                    var dlt:Number = Number(entry.delta);

                    item.num.htmlText   = _fmt(String(num), FONT_BATTLE_NUM, COLOR_TEXT);
                    item.dmg.htmlText   = _fmt((dmg > 0 ? _fmtNum(dmg) : "-"),
                                               FONT_BATTLE_NUM, dmg > 0 ? COLOR_TEXT : COLOR_DIM);
                    item.delta.htmlText = _fmtDeltaHTML(dlt);
                }
                else
                {
                    item.num.htmlText   = _fmt("-", FONT_BATTLE_NUM, COLOR_DIM);
                    item.dmg.htmlText   = _fmt("-", FONT_BATTLE_NUM, COLOR_DIM);
                    item.delta.htmlText = _fmt("-", FONT_BATTLE_NUM, COLOR_DIM);
                }
                item.num.visible   = true;
                item.dmg.visible   = true;
                item.delta.visible = true;
                item.num.x   = listX + 4;
                item.num.y   = rowY;
                item.dmg.x   = listX + 50;
                item.dmg.y   = rowY;
                item.delta.x = listX + 130;
                item.delta.y = rowY;
            }
        }

        private function _layoutGraph():void
        {
            var g:Graphics = _graphLayer.graphics;
            g.clear();

            var top:int    = PAD + HEADER_H + PROGRESS_TOP_GAP + PROGRESS_H + PROGRESS_BOTTOM_GAP + BLOCK_ROW_H + 12;
            var listW:int  = 200;
            var left:int   = PAD + listW + GRAPH_LEFT_AXIS;

            var right:int  = W - PAD - 36;
            var bottom:int = top + GRAPH_H;
            var width:int  = right - left;
            var height:int = GRAPH_H;

            var values:Array = [];
            for (var i:int = 0; i < _history.length; i++)
                values.push(Number(_history[i].value));

            var hasData:Boolean = values.length > 0;
            var anchor:Number = hasData ? Number(values[values.length - 1]) :
                               (isNaN(_currentMark) ? 0 : _currentMark);

            var minV:Number = anchor - 1.5;
            var maxV:Number = anchor + 1.5;
            for (i = 0; i < values.length; i++)
            {
                if (values[i] < minV) minV = values[i];
                if (values[i] > maxV) maxV = values[i];
            }
            minV = Math.floor(minV * 2) / 2;
            maxV = Math.ceil(maxV * 2)  / 2;
            if (maxV - minV < 1) maxV = minV + 1;
            if (minV < 0)   minV = 0;
            if (maxV > 100) maxV = 100;

            var range:Number = maxV - minV;
            var labelCount:int = 5;
            var stepRaw:Number = range / (labelCount - 1);
            var stepY:Number;
            if      (stepRaw >= 4)   stepY = Math.ceil(stepRaw);
            else if (stepRaw >= 2)   stepY = 2;
            else                     stepY = 1;
            var topV:Number = Math.ceil(maxV / stepY) * stepY;
            var botV:Number = topV - stepY * (labelCount - 1);
            if (botV < 0) { botV = 0; topV = botV + stepY * (labelCount - 1); }
            minV  = botV;
            maxV  = topV;
            range = maxV - minV;

            for (i = 0; i < _axisLabels.length; i++)
            {
                var tf:TextField = _axisLabels[i] as TextField;
                if (i >= labelCount) { tf.visible = false; continue; }
                var ratio:Number = i / (labelCount - 1);
                var v:Number = maxV - ratio * stepY * (labelCount - 1);
                tf.visible = true;
                tf.htmlText = _fmt(int(Math.round(v)) + "%", FONT_AXIS, COLOR_LABEL);
                tf.x = left - 8 - tf.width;
                tf.y = top + ratio * height - 8;
            }

            for (i = 0; i < labelCount; i++)
            {
                var ratio2:Number = i / (labelCount - 1);
                var gy:Number = top + ratio2 * height;
                if (i == labelCount - 1)
                {
                    g.lineStyle(0.5, COLOR_GRID, 0.30);
                    g.moveTo(left, gy);
                    g.lineTo(right, gy);
                }
                else
                {
                    g.lineStyle(0.5, COLOR_GRID, 0.10);
                    var dashX:Number = left;
                    while (dashX + 3 < right)
                    {
                        g.moveTo(dashX,     gy);
                        g.lineTo(dashX + 3, gy);
                        dashX += 6;
                    }
                }
            }
            g.lineStyle(NaN);

            _yAxisUnitTf.htmlText = _fmt("%", FONT_AXIS, COLOR_LABEL);
            _yAxisUnitTf.x = left - 8 - _yAxisUnitTf.width;
            _yAxisUnitTf.y = top - _yAxisUnitTf.height - 2;
            _yAxisUnitTf.visible = true;

            if (!hasData)
            {
                _markLabel.visible = false;
                for (i = 0; i < _xAxisLabels.length; i++)
                    (_xAxisLabels[i] as TextField).visible = false;
                _xAxisUnitTf.visible = false;
                return;
            }

            var n:int = values.length;
            var step:Number;
            var pts:Array = [];
            if (n == 1)
            {
                step = 0;
                var rawPy0:Number = bottom - ((Number(values[0]) - minV) / range) * height;
                var py0:Number = Math.max(top, Math.min(bottom, rawPy0));
                pts.push(new Point(left, py0));
                pts.push(new Point(right, py0));
            }
            else
            {
                step = width / (n - 1);
                for (i = 0; i < n; i++)
                {
                    var px:Number = left + i * step;
                    var rawPy:Number = bottom - ((Number(values[i]) - minV) / range) * height;
                    var py:Number = Math.max(top, Math.min(bottom, rawPy));
                    pts.push(new Point(px, py));
                }
            }

            if (pts.length >= 2 && n >= 2)
            {
                var areaMatrix:Matrix = new Matrix();
                areaMatrix.createGradientBox(width, height, Math.PI / 2, left, top);
                g.beginGradientFill(GradientType.LINEAR,
                    [COLOR_LINE, COLOR_LINE],
                    [0.18, 0.0],
                    [0, 255], areaMatrix);
                g.moveTo(pts[0].x, pts[0].y);
                for (i = 1; i < pts.length; i++)
                    g.lineTo(pts[i].x, pts[i].y);
                g.lineTo(pts[pts.length - 1].x, bottom);
                g.lineTo(pts[0].x, bottom);
                g.endFill();
            }

            if (pts.length >= 2)
            {
                if (n == 1)
                {
                    g.lineStyle(1.5, COLOR_LINE, 0.4);
                }
                else
                {
                    g.lineStyle(1.8, COLOR_LINE, 0.95);
                }
                g.moveTo(pts[0].x, pts[0].y);
                for (i = 1; i < pts.length; i++)
                    g.lineTo(pts[i].x, pts[i].y);
                g.lineStyle(NaN);
            }

            var dotStart:int = (n == 1) ? 1 : 0;
            for (i = dotStart; i < pts.length - 1; i++)
            {
                g.beginFill(0xFFFFFF, 0.7);
                g.drawCircle(pts[i].x, pts[i].y, 2.5);
                g.endFill();
            }

            var lastPt:Point = pts[pts.length - 1] as Point;
            g.lineStyle(1, 0xFFFFFF, 0.35);
            g.beginFill(0x000000, 0);
            g.drawCircle(lastPt.x, lastPt.y, 6);
            g.endFill();
            g.lineStyle(0);
            g.beginFill(0xFFFFFF, 0.95);
            g.drawCircle(lastPt.x, lastPt.y, 3);
            g.endFill();

            g.lineStyle(0.5, 0xFFFFFF, 0.2);
            var dashY:Number = lastPt.y + 6;
            while (dashY + 4 < bottom)
            {
                g.moveTo(lastPt.x, dashY);
                g.lineTo(lastPt.x, dashY + 4);
                dashY += 7;
            }
            g.lineStyle(NaN);

            var labelStr:String = _fmt2(Number(values[values.length - 1])) + "%";
            _markLabel.htmlText = _fmt(labelStr, 11, 0xFFFFFF);

            var pillPadH:Number  = 7;
            var pillPadV:Number  = 1;
            var tailH:Number     = 5;
            var tailHalfW:Number = 4;
            var gapAboveDot:Number = 5;

            var pillW:Number = _markLabel.width + pillPadH * 2;
            var pillH:Number = _markLabel.height + pillPadV * 2;
            var pillR:Number = pillH * 0.5;

            var tailTipX:Number = lastPt.x;
            var tailTipY:Number = lastPt.y - gapAboveDot;
            var pillX:Number = tailTipX - pillW * 0.5;
            var pillY:Number = tailTipY - tailH - pillH;

            var minPillX:Number = left + 4;
            var maxPillX:Number = right - pillW + 16;
            if (pillX < minPillX) pillX = minPillX;
            if (pillX > maxPillX) pillX = maxPillX;

            var tailPointsUp:Boolean = false;
            if (pillY < top + 1)
            {
                tailPointsUp = true;
                tailTipY = lastPt.y + gapAboveDot;
                pillY = tailTipY + tailH;
            }

            var tailAnchorX:Number = tailTipX;
            var tailMinX:Number = pillX + pillR + tailHalfW;
            var tailMaxX:Number = pillX + pillW - pillR - tailHalfW;
            if (tailAnchorX < tailMinX) tailAnchorX = tailMinX;
            if (tailAnchorX > tailMaxX) tailAnchorX = tailMaxX;

            g.lineStyle(0.75, 0xC8B97A, 0.5);
            g.beginFill(0x0A0E12, 0.95);
            g.drawRoundRect(pillX, pillY, pillW, pillH, pillR * 2, pillR * 2);
            g.endFill();

            g.lineStyle(NaN);
            g.beginFill(0x0A0E12, 0.95);
            var baseY:Number = tailPointsUp ? pillY : pillY + pillH;
            g.moveTo(tailAnchorX - tailHalfW, baseY);
            g.lineTo(tailAnchorX + tailHalfW, baseY);
            g.lineTo(tailTipX,                tailTipY);
            g.lineTo(tailAnchorX - tailHalfW, baseY);
            g.endFill();

            g.lineStyle(0.75, 0xC8B97A, 0.5);
            g.moveTo(tailAnchorX - tailHalfW, baseY);
            g.lineTo(tailTipX,                tailTipY);
            g.lineTo(tailAnchorX + tailHalfW, baseY);
            g.lineStyle(NaN);

            _markLabel.x = pillX + pillPadH;
            _markLabel.y = pillY + pillPadV;
            _markLabel.visible = true;

            var totalX:int = _xAxisLabels.length;
            var idxs:Array = [];
            if (n == 1)        idxs = [0];
            else if (n == 2)   idxs = [0, 1];
            else if (n <= 4)   { for (i = 0; i < n; i++) idxs.push(i); }
            else
            {
                idxs.push(0);
                idxs.push(int((n - 1) / 3));
                idxs.push(int((n - 1) * 2 / 3));
                idxs.push(n - 1);
            }
            for (i = 0; i < totalX; i++)
            {
                var xtf:TextField = _xAxisLabels[i] as TextField;
                if (i >= idxs.length) { xtf.visible = false; continue; }
                var ix:int = int(idxs[i]);
                var entry2:Object = (ix < _history.length) ? _history[ix] : null;
                var num:int;
                if (entry2 != null)
                {
                    num = int(entry2.num);
                }
                else if (_history.length > 0)
                {
                    var lastEntry:Object = _history[_history.length - 1];
                    num = int(lastEntry.num) + (ix - _history.length + 1);
                }
                else
                {
                    num = ix + 1;
                }
                xtf.visible = true;
                xtf.htmlText = _fmt(String(num), FONT_AXIS, COLOR_LABEL);
                if (n == 1)
                    xtf.x = right - xtf.width * 0.5;     // single battle: right side
                else
                    xtf.x = left + ix * step - xtf.width * 0.5;
                xtf.y = bottom + 4;
            }

            _xAxisUnitTf.htmlText = _fmt("№", FONT_AXIS, COLOR_DIM);
            _xAxisUnitTf.x = right + 10;
            _xAxisUnitTf.y = bottom + 4;
            _xAxisUnitTf.visible = true;
        }


        private function _findBestIdx():int
        {
            if (_history.length == 0) return -1;
            var best:int = -1;
            var bestDelta:Number = -Infinity;
            for (var i:int = 0; i < _history.length; i++)
            {
                var d:Number = Number(_history[i].delta);
                if (!isNaN(d) && d > bestDelta)
                {
                    bestDelta = d;
                    best = i;
                }
            }
            return best;
        }

        private function _avgDelta(window:int):Number
        {
            if (_history.length == 0) return NaN;
            var n:int = Math.min(window, _history.length);
            var startIdx:int = _history.length - n;
            var total:Number = 0;
            for (var i:int = startIdx; i < _history.length; i++)
            {
                var delta:Number = Number(_history[i].delta);
                if (!isNaN(delta)) total += delta;
            }
            return total;
        }

        private function _mkText(size:int, color:uint, autoSize:String):TextField
        {
            var tf:TextField = new TextField();
            tf.selectable   = false;
            tf.mouseEnabled  = false;
            tf.autoSize      = autoSize;
            tf.multiline     = false;
            tf.filters       = [_textShadow];
            _root.addChild(tf);
            return tf;
        }

        private function _fmt(text:String, size:int, color:uint):String
        {
            return '<font face="' + FONT_FACE + '" size="' + size + '" color="'
                 + _hex(color) + '"><b>' + text + '</b></font>';
        }

        private function _fmtDeltaHTML(delta:Number):String
        {
            if (isNaN(delta))
                return _fmt("-", FONT_DELTA, COLOR_DIM);
            var color:uint;
            if (delta > 0.005)       color = COLOR_DELTA_UP;
            else if (delta < -0.005) color = COLOR_DELTA_DOWN;
            else                     color = COLOR_DELTA_FLAT;
            var sign:String = (delta > 0.005) ? "+" : "";
            return _fmt(sign + _fmt2(delta) + "%", FONT_DELTA, color);
        }

        private function _fmtPercent(value:Number, fallback:String):String
        {
            if (isNaN(value)) return fallback;
            return _fmt2(value) + "%";
        }

        private static function _fmt2(value:Number):String
        {
            var v:Number = value;
            if (isNaN(v)) return "-";
            var sign:String = "";
            if (v < 0) { sign = "-"; v = -v; }
            var rounded:Number = Math.round(v * 100) / 100;
            var intPart:int = int(rounded);
            var frac:int    = int(Math.round((rounded - intPart) * 100));
            var fracStr:String = String(frac);
            if (fracStr.length < 2) fracStr = "0" + fracStr;
            return sign + intPart.toString() + "." + fracStr;
        }

        private static function _hex(color:uint):String
        {
            var h:String = color.toString(16).toUpperCase();
            while (h.length < 6) h = "0" + h;
            return "#" + h;
        }

        private static function _safeStr(s:String, fallback:String):String
        {
            return (s != null && s.length > 0) ? s : fallback;
        }

        private function _fmtNum(value:int):String
        {
            var neg:Boolean = value < 0;
            var abs:int     = neg ? -value : value;
            var s:String    = String(abs);
            var result:String = "";
            var count:int   = 0;
            for (var i:int = s.length - 1; i >= 0; i--)
            {
                if (count > 0 && count % 3 == 0) result = " " + result;
                result = s.charAt(i) + result;
                count++;
            }
            return neg ? ("-" + result) : result;
        }
    }
}
