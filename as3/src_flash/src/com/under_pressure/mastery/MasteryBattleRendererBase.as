package com.under_pressure.mastery
{
    import flash.display.CapsStyle;
    import flash.display.Graphics;
    import flash.display.GradientType;
    import flash.display.Shape;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.events.MouseEvent;
    import flash.filters.DropShadowFilter;
    import flash.filters.GlowFilter;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.AntiAliasType;
    import flash.text.GridFitType;
    import flash.ui.Keyboard;

    public class MasteryBattleRendererBase extends Sprite
    {
        private static const W:int      = 201;
        private static const H:int      = 91;
        private static const H_EXP:int  = 115;
        // ── Стилі мітки (кожен має свій рендер-блок нижче) ──
        // 0 = classic   — рамка з кутами, зірки по центру
        // 1 = compact   — зірки+лінії зліва, сегментний бар
        // 2 = polaroid  — колишній HTML-стиль (не чіпати без потреби)
        // 3 = neer      — золотий танк, заливка по %
        // 4 = minimal   — простий текст
        public static const STYLE_CLASSIC:int  = 0;
        public static const STYLE_COMPACT:int  = 1;
        public static const STYLE_POLAROID:int = 2;
        public static const STYLE_NEER:int     = 3;
        public static const STYLE_MINIMAL:int  = 4;
        public static const STYLE_COUNT:int    = 5;

        private static const W_HTML:int     = 198;
        private static const H_HTML:int     = 103;
        private static const H_HTML_EXP:int = 157;
        private static const HTML_X_SCALE:Number = 1.0;
        private static const BATTLE_EDGE_GAP:int = 4;
        private static const PAD:int    = 24;

        private function _curW():int
        {
            if (_style == STYLE_POLAROID) return W_HTML;
            if (_style == STYLE_NEER)     return int(W * 2);          // neer масштабований ×2
            return W;
        }
        private function _curH():int
        {
            if (_style == STYLE_POLAROID) return _expanded ? H_HTML_EXP : H_HTML;
            if (_style == STYLE_NEER)     return int(260 * (W / 406.0) * 2.0); // реальна висота neer
            return _expanded ? H_EXP : H;
        }
        private function _hx(value:Number):Number { return Math.round(value * HTML_X_SCALE); }
        private static const FONT_FACE:String  = "$FieldFont";
        private static const TITLE_FONT_FACE:String = "$TitleFont";
        private static const COLOR_LABEL:uint  = 0xFFFFFF;
        private static const COLOR_DIM:uint    = 0x98A6B3;
        private static const COLOR_GREEN:uint  = 0xB6E86A;
        private static const COLOR_RED:uint    = 0xD64A4A;
        private static const COLOR_GOLD:uint   = 0xC8B97A;
        private static const FRAME_COLOR:uint  = 0xAEB8C2;
        private static const FRAME_DARK:uint   = 0x141A22;
        private static const HTML_FRAME_COLOR:uint = 0xCCCCCC;
        private static const HTML_FRAME_LIGHT:uint = 0xCECECE;
        private static const HTML_FRAME_MID:uint = 0xCACACA;
        private static const HTML_FRAME_DARK:uint = 0xB3B3B3;
        private static const HTML_RED:uint = 0xF16868;
        private static const HTML_GREEN:uint = 0xA6E176;
        private static const HTML_ARROW_RED:uint = 0xF16868;    // стрілка (світліший)
        private static const HTML_BAR_RED:uint = 0xE93D3D;      // прогрес-бар
        // delta arrow colours: up / down / zero
        private static const ARROW_UP:uint     = 0x82B15C;
        private static const ARROW_DOWN:uint   = 0xBE5151;
        private static const ARROW_ZERO:uint   = 0xE6E6E6;

        // milestone colours: 1 star 65%, 2 stars 85%, 3 stars 95%
        private static const MILESTONE_PCTS:Array  = [65.0, 85.0, 95.0];
        private static const MILESTONE_LABELS:Array = ["1\u2605  65%", "2\u2605  85%", "3\u2605  95%"];
        private static const MILESTONE_COLORS:Array = [0x78909C, 0xC0C0C0, 0xC8B97A];

        private var _bg:Shape;
        private var _dragHit:Sprite;
        private var _line:Shape;        // main progress bar
        private var _targetLine:Shape;  // milestone progress bar (expanded)
        private var _stars:Shape;
        private var _arrow:Shape;       // delta direction arrow (up/down/zero)
        private var _value:TextField;
        private var _total:TextField;
        private var _targetLabel:TextField;
        private var _targetDmg:TextField;
        private var _delta:TextField;   // delta % shown next to value
        private var _htmlSumValue:TextField;
        private var _htmlSumTarget:TextField;
        private var _htmlTempoValue1:TextField;
        private var _htmlTempoValue2:TextField;
        private var _shadow:DropShadowFilter;
        private var _style3Outline:Shape;
        private var _collapseBtn:Sprite;

        // окремі рендери для складних стилів (створюються лениво)
        private var _neerRenderer:MasteryNeerRenderer;
        private var _minimalRenderer:MasteryMinRenderer;

        private var _mark:Number       = 0.0;
        private var _p65:int           = 0;
        private var _p85:int           = 0;
        private var _p95:int           = 0;
        private var _p100:int          = 0;
        private var _currentDamage:int = -1;
        private var _baseDamage:int    = 0;
        private var _projectedMark:Number = -1.0;
        private var _projectedAvg:int  = 0;
        private var _starsCount:int    = -1;
        private var _expanded:Boolean  = false;
        private var _disposed:Boolean  = false;
        private var _offset:Array      = [-1, -1];
        private var _dragging:Boolean  = false;
        private var _panelCollapsed:Boolean = false;
        private var _controlVisible:Boolean = false;
        // 0 = classic (зірки/число по центру), 1 = compact (зірки+смужки зліва)
        private var _style:int         = 0;

        public function MasteryBattleRendererBase()
        {
            super();
            mouseEnabled  = true;
            mouseChildren = true;
            visible       = false;
            _shadow = new DropShadowFilter(1.2, 45, 0x000000, 0.95, 3, 3, 1.6, 1);

            _dragHit     = new Sprite(); addChild(_dragHit);
            _dragHit.mouseEnabled = true;
            _dragHit.mouseChildren = false;
            _dragHit.addEventListener(MouseEvent.MOUSE_DOWN, _onMouseDown);
            _bg          = new Shape();  addChild(_bg);
            _style3Outline = new Shape(); addChild(_style3Outline);
            _line        = new Shape();  addChild(_line);
            _targetLine  = new Shape();  addChild(_targetLine);
            _stars       = new Shape();  addChild(_stars);
            _arrow       = new Shape();  addChild(_arrow);
            _value       = _makeText(24, COLOR_LABEL);
            _total       = _makeText(12, COLOR_DIM);
            _targetLabel = _makeText(12, COLOR_DIM);
            _targetDmg   = _makeText(12, COLOR_DIM);
            _delta       = _makeText(14, COLOR_GREEN);
            _htmlSumValue = _makeText(15, COLOR_LABEL);
            _htmlSumTarget = _makeText(13, COLOR_LABEL);
            _htmlTempoValue1 = _makeText(13, COLOR_LABEL);
            _htmlTempoValue2 = _makeText(13, COLOR_LABEL);
            addChild(_value);
            addChild(_total);
            addChild(_targetLabel);
            addChild(_targetDmg);
            addChild(_delta);
            addChild(_htmlSumValue);
            addChild(_htmlSumTarget);
            addChild(_htmlTempoValue1);
            addChild(_htmlTempoValue2);
            _collapseBtn = new Sprite();
            _collapseBtn.mouseEnabled = true;
            _collapseBtn.mouseChildren = false;
            _collapseBtn.buttonMode = true;
            _collapseBtn.useHandCursor = true;
            _collapseBtn.visible = false;
            _collapseBtn.addEventListener(MouseEvent.MOUSE_DOWN, _onCollapseMouseDown);
            _collapseBtn.addEventListener(MouseEvent.CLICK, _onCollapseClick);
            addChild(_collapseBtn);

            addEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
            addEventListener(MouseEvent.MOUSE_DOWN, _onMouseDown);
            _draw();
        }

        // ── public API ───────────────────────────────────────────────────────

        public function setExpanded(value:Boolean):void
        {
            if (_disposed) return;
            if (_expanded == value) return;
            _expanded = value;
            _draw();
            updatePosition();
        }

        public function setStyle(value:int):void
        {
            if (_disposed) return;
            var v:int = value;
            if (v < 0 || v >= STYLE_COUNT) v = STYLE_CLASSIC;
            if (_style == v) return;
            _style = v;
            _draw();
            updatePosition();
        }

        public function setData(mark:Number, p65:int, p85:int, p95:int, p100:int,
                                currentDamage:int, baseDamage:int, stars:int,
                                projectedMark:Number = -1.0, projectedAvg:int = 0):void
        {
            _mark          = isNaN(mark)          ? 0.0  : mark;
            _p65           = int(Math.max(0, p65));
            _p85           = int(Math.max(0, p85));
            _p95           = int(Math.max(0, p95));
            _p100          = int(Math.max(0, p100));
            _currentDamage = int(Math.max(-1, currentDamage));
            _baseDamage    = int(Math.max(0,  baseDamage));
            _projectedMark = isNaN(projectedMark) ? -1.0 : projectedMark;
            _projectedAvg  = int(Math.max(0, projectedAvg));
            _starsCount    = int(Math.max(-1, Math.min(3, stars)));
            _draw();
            updatePosition();
        }

        public function setCurrentDamage(value:int):void
        {
            _currentDamage = int(Math.max(0, value));
            _projectedMark = -1.0;
            _projectedAvg  = 0;
            _draw();
        }

        public function setPositionOffset(offset:Array):void
        {
            if (offset && offset.length >= 2)
                _offset = [int(offset[0]), int(offset[1])];
            updatePosition();
        }

        public function updatePosition():void
        {
            if (!stage || _dragging) return;
            var sw:int = stage.stageWidth  > 0 ? stage.stageWidth  : 1280;
            var sh:int = stage.stageHeight > 0 ? stage.stageHeight : 720;
            var h:int  = _curH();
            var ww:int = _curW();
            if (_offset[0] < 0 && _offset[1] < 0)
            {
                x = int(sw * 0.5 - ww * 0.5);
                y = int(sh - h - 118);
            }
            else
            {
                x = Math.max(BATTLE_EDGE_GAP, Math.min(sw - ww - BATTLE_EDGE_GAP,  int(_offset[0])));
                y = Math.max(BATTLE_EDGE_GAP, Math.min(sh - h - BATTLE_EDGE_GAP,  int(_offset[1])));
            }
        }

        public function dispose():void
        {
            if (_disposed) return;
            _disposed = true;
            removeEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
            removeEventListener(MouseEvent.MOUSE_DOWN, _onMouseDown);
            if (_dragHit)
                _dragHit.removeEventListener(MouseEvent.MOUSE_DOWN, _onMouseDown);
            if (_collapseBtn)
            {
                _collapseBtn.removeEventListener(MouseEvent.MOUSE_DOWN, _onCollapseMouseDown);
                _collapseBtn.removeEventListener(MouseEvent.CLICK, _onCollapseClick);
            }
            if (stage)
            {
                stage.removeEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
                stage.removeEventListener(KeyboardEvent.KEY_UP,   _onKeyUp);
                stage.removeEventListener(MouseEvent.MOUSE_UP,    _onMouseUp);
                stage.removeEventListener(Event.MOUSE_LEAVE,      _onMouseLeave);
            }
            // звільняємо BitmapData буфери neer (інакше витік пам'яті між боями)
            if (_neerRenderer)
            {
                _neerRenderer.dispose();
                if (_neerRenderer.parent) _neerRenderer.parent.removeChild(_neerRenderer);
                _neerRenderer = null;
            }
            if (_minimalRenderer)
            {
                if (_minimalRenderer.parent) _minimalRenderer.parent.removeChild(_minimalRenderer);
                _minimalRenderer = null;
            }
        }

        // ── keyboard / mouse ─────────────────────────────────────────────────

        private function _onAddedToStage(e:Event):void
        {
            removeEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
            stage.addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
            stage.addEventListener(KeyboardEvent.KEY_UP,   _onKeyUp);
        }

        private function _onKeyDown(e:KeyboardEvent):void
        {
            if (e.keyCode == Keyboard.ALTERNATE && !_expanded)
            {
                _expanded = true;
                _draw();
                updatePosition();
            }
            if (e.keyCode == Keyboard.CONTROL)
            {
                _controlVisible = true;
                _drawCollapseButton();
            }
        }

        private function _onKeyUp(e:KeyboardEvent):void
        {
            if (e.keyCode == Keyboard.ALTERNATE && _expanded)
            {
                _expanded = false;
                _draw();
                updatePosition();
            }
            if (e.keyCode == Keyboard.CONTROL)
            {
                _controlVisible = false;
                _drawCollapseButton();
            }
        }

        private function _onMouseDown(e:MouseEvent):void
        {
            if (!stage) return;
            if (_collapseBtn && _collapseBtn.visible && _collapseBtn.hitTestPoint(stage.mouseX, stage.mouseY, true))
                return;
            _dragging = true;
            var bounds:Rectangle = new Rectangle(
                BATTLE_EDGE_GAP, BATTLE_EDGE_GAP,
                Math.max(0, stage.stageWidth  - _curW() - BATTLE_EDGE_GAP * 2),
                Math.max(0, stage.stageHeight - _curH() - BATTLE_EDGE_GAP * 2)
            );
            startDrag(false, bounds);
            stage.addEventListener(MouseEvent.MOUSE_UP, _onMouseUp);
            stage.addEventListener(Event.MOUSE_LEAVE, _onMouseLeave);
            e.stopPropagation();
        }

        private function _onMouseUp(e:MouseEvent):void
        {
            _finishDrag();
        }

        private function _onMouseLeave(e:Event):void
        {
            _finishDrag();
        }

        private function _finishDrag():void
        {
            if (!_dragging) return;
            stopDrag();
            if (stage)
            {
                stage.removeEventListener(MouseEvent.MOUSE_UP, _onMouseUp);
                stage.removeEventListener(Event.MOUSE_LEAVE, _onMouseLeave);
            }
            _dragging = false;
            _offset = [int(x), int(y)];
            dispatchEvent(new MasteryPanelEvent(MasteryPanelEvent.BATTLE_BADGE_OFFSET_CHANGED, _offset));
        }

        private function _onCollapseMouseDown(e:MouseEvent):void
        {
            e.stopImmediatePropagation();
        }

        private function _onCollapseClick(e:MouseEvent):void
        {
            e.stopImmediatePropagation();
            _panelCollapsed = !_panelCollapsed;
            if (!_panelCollapsed) _controlVisible = false;
            _draw();
            updatePosition();
        }

        // ── draw ─────────────────────────────────────────────────────────────

        private function _draw():void
        {
            var isPolaroid:Boolean = (_style == STYLE_POLAROID);
            _setPanelContentVisible(true);
            _setTextFilters(isPolaroid);
            // HTML-асети (рамка/фон) — ТІЛЬКИ для polaroid, не для neer
            _setStyle3AssetsVisible(isPolaroid);
            if (!isPolaroid)
            {
                if (_style3Outline) _style3Outline.graphics.clear();
                if (_htmlSumValue) _htmlSumValue.visible = false;
                if (_htmlSumTarget) _htmlSumTarget.visible = false;
                if (_htmlTempoValue1) _htmlTempoValue1.visible = false;
                if (_htmlTempoValue2) _htmlTempoValue2.visible = false;
            }

            // ховаємо окремі рендери якщо активний інший стиль
            if (_neerRenderer && _style != STYLE_NEER) _neerRenderer.visible = false;
            if (_minimalRenderer && _style != STYLE_MINIMAL) _minimalRenderer.visible = false;

            // ── диспетч стилів ──
            switch (_style)
            {
                case STYLE_COMPACT:  _drawCompact();    break;
                case STYLE_POLAROID: _drawHtmlStyle();  break;
                case STYLE_NEER:     _drawNeerStyle();  break;
                case STYLE_MINIMAL:  _drawMinimalStyle(); break;
                default:             _drawClassic();    break;
            }
            _drawCollapseButton();
        }

        // ── CLASSIC (style 0): рамка з кутами, зірки по центру ────────────────
        private function _drawClassic():void
        {
            var h:int = _expanded ? H_EXP : H;

            var g:Graphics = _bg.graphics;
            g.clear();
            g.lineStyle(0, 0x000000, 0.0);
            g.beginFill(0x05080C, 0.001);
            g.drawRoundRect(0, 0, W, h, 4, 4);
            g.endFill();
            _drawFrameSegments(g, W, h, 56);

            // computed values
            var current:int       = _currentDamage >= 0 ? _currentDamage : 0;
            var projAvg:int       = _projectedAvg > 0 ? _projectedAvg : _projectedAverage(current);
            var projMark:Number   = _projectedMark >= 0.0 ? _projectedMark :
                                    (projAvg > 0 ? _estimateMarkFromDamage(projAvg) : _mark);
            var delta:Number      = projMark - _mark;
            var deltaColor:uint   = Math.abs(delta) < 0.005 ? COLOR_DIM : (delta > 0 ? COLOR_GREEN : COLOR_RED);

            // stars + main value + delta arrow
            _drawStars(projMark);

            var kind:int = Math.abs(delta) < 0.005 ? 0 : (delta > 0 ? 1 : -1); // 0=zero 1=up -1=down
            var valStr:String   = _fmt2(projMark) + "%";
            var deltaStr:String = (kind == 0) ? "" : ((delta > 0 ? "+" : "") + _fmt2(delta) + "%");

            _value.htmlText = _fmtBold(valStr, 25, COLOR_LABEL);
            var valW:Number   = _value.width;

            var deltaW:Number = 0;
            if (deltaStr.length > 0)
            {
                _delta.htmlText = _fmtBold(deltaStr, 15, deltaColor);
                deltaW = _delta.width;
                _delta.visible = true;
            }
            else
            {
                _delta.visible = false;
            }

            var arrowGap:Number = (kind == 0 ? 16 : 28);
            var blockW:Number   = valW + arrowGap + deltaW;
            var blockX:Number   = int(W / 2 - blockW / 2);
            _value.x = blockX;
            _value.y = 22;

            // arrow placed with clear margin from both value and delta
            _drawArrow(blockX + valW + 8, 35, kind);

            // delta text after the arrow (extra margin so they never touch)
            if (deltaStr.length > 0)
            {
                _delta.x = int(blockX + valW + arrowGap);
                _delta.y = 30;
            }

            // main progress bar: 0 → baseDamage (скільки треба щоб не впасти)
            var nearestIdx:int    = _nearestMilestone(projMark);
            var nearestDmg:int    = _milestoneRequiredDamage(nearestIdx);
            _drawProgressBar(_line, current, _baseDamage > 0 ? _baseDamage : nearestDmg, delta, 56);

            // "Current / target" line (без підпису)
            var baseTarget:int = _baseDamage > 0 ? _baseDamage : (nearestDmg > 0 ? nearestDmg : (_p85 > 0 ? _p85 : 0));
            _total.htmlText = _fmtBold(_fmtNum(current), 14, COLOR_LABEL) +
                              _fmt(" / " + (baseTarget > 0 ? _fmtNum(baseTarget) : "N/A"), 14, COLOR_DIM);
            // Сумарний прогрес під планкою — по центру.
            _total.x = int(W / 2 - _total.width / 2);
            _total.y = 68;

            // ── expanded: nearest milestone ──────────────────────────────────
            _targetLine.visible  = _expanded;
            _targetLabel.visible = _expanded;
            _targetDmg.visible   = _expanded;

            if (_expanded)
            {
                var milestoneIdx:int      = _nearestMilestone(projMark);
                var milestonePct:Number   = Number(MILESTONE_PCTS[milestoneIdx]);
                var milestoneColor:uint   = uint(MILESTONE_COLORS[milestoneIdx]);
                var milestoneDmg:int      = _milestoneRequiredDamage(milestoneIdx);

                // Просто текст: "85%  3 761" без полосок
                var pctStr:String = milestonePct.toFixed(0) + "%";
                var dmgStr:String = _fmtNum(milestoneDmg);
                _targetLabel.htmlText = _fmt(pctStr + "  " + dmgStr, 16, milestoneColor);
                _targetLabel.x = int(W / 2 - _targetLabel.width / 2);
                _targetLabel.y = 91;

                _targetDmg.htmlText = "";
                _targetLine.graphics.clear();
            }
        }

        // ── compact style (зірки+смужки зліва, як на макеті) ─────────────────
        private static const COMPACT_DIM_WHITE:uint = 0xCED6DE;

        private function _drawHtmlStyle():void
        {
            var g:Graphics = _bg.graphics;
            g.clear();

            // мінімальна radial-підкладка ззаду — робить мітку видимішою в бою
            var glowW:Number = W_HTML + 80;
            var glowH:Number = (_expanded ? H_HTML_EXP : H_HTML) + 60;
            var gm:Matrix = new Matrix();
            gm.createGradientBox(glowW, glowH, 0, (W_HTML - glowW) / 2, ((_expanded ? H_HTML_EXP : H_HTML) - glowH) / 2);
            g.beginGradientFill(GradientType.RADIAL,
                [0x000000, 0x000000], [0.22, 0.0], [0, 255], gm);
            g.drawRect((W_HTML - glowW) / 2, ((_expanded ? H_HTML_EXP : H_HTML) - glowH) / 2, glowW, glowH);
            g.endFill();

            var current:int     = _currentDamage >= 0 ? _currentDamage : 0;
            var projAvg:int     = _projectedAvg > 0 ? _projectedAvg : _projectedAverage(current);
            var projMark:Number = _projectedMark >= 0.0 ? _projectedMark :
                                  (projAvg > 0 ? _estimateMarkFromDamage(projAvg) : _mark);
            var delta:Number    = projMark - _mark;
            var kind:int        = Math.abs(delta) < 0.005 ? 0 : (delta > 0 ? 1 : -1);
            var filled:int      = _starsCount >= 0 ? _starsCount : 0;
            var noData:Boolean  = (_p65 <= 0 && _p85 <= 0 && _p95 <= 0 && _p100 <= 0);
            _drawStyle3BattleOutline(_expanded);
            if (noData)
            {
                _stars.graphics.clear();
                _line.graphics.clear();
                _targetLine.graphics.clear();
                _arrow.graphics.clear();
                _value.htmlText = _fmtTitle("-- --", 28, COLOR_LABEL);
                _value.x = 5;
                _value.y = 14;
                _total.htmlText = _fmt("\u041f\u0440\u043e\u0432\u0435\u0434\u0456\u0442\u044c \u0431\u0456\u043b\u044c\u0448\u0435 \u0431\u043e\u0457\u0432", 11, COLOR_LABEL);
                _total.x = 6;
                _total.y = 74;
                _htmlSumValue.visible = false;
                _htmlSumTarget.visible = false;
                _htmlTempoValue1.visible = false;
                _htmlTempoValue2.visible = false;
                _targetLabel.visible = false;
                _targetDmg.visible = false;
                _delta.visible = false;
                _drawCollapseButton();
                return;
            }

            var sg:Graphics = _stars.graphics;
            sg.clear();
            var i:int;
            for (i = 0; i < 3; i++)
            {
                sg.lineStyle(1.0, FRAME_COLOR, 0.55, true);
                sg.beginFill(i < filled ? 0xFFFFFF : 0x27313C, 1.0);
                _starPath(sg, 84 + i * 15, 0, 7, 3.0);
                sg.endFill();
            }

            _value.htmlText = _fmtTitle(_fmt2(projMark) + "%", 28, COLOR_LABEL);
            _value.x = 14;
            _value.y = 14;

            var deltaStr:String = (kind == 0) ? "" :
                ((delta > 0 ? "+" : "-") + _fmt2(Math.abs(delta)) + "%");
            if (deltaStr.length > 0)
            {
                // delta-число — сіре (як "Загалом"), не червоне/зелене
                _delta.htmlText = _fmt(deltaStr, 16, COLOR_DIM);
                _delta.x = 122;
                _delta.y = 23;
                _delta.visible = true;
            }
            else
            {
                _delta.visible = false;
            }
            _drawTrendArrow(112, 31, kind);

            var nearestIdx:int = _nearestMilestone(projMark);
            var nearestDmg:int = _milestoneRequiredDamage(nearestIdx);
            var target:int     = _baseDamage > 0 ? _baseDamage : nearestDmg;
            _drawForecastMarkBarSquare(_line, projMark, delta, 24, 150, 58, 4.0, 0, W_HTML);
            _drawStyle3DetailLine(_expanded);

            var currentColor:uint = kind > 0 ? HTML_GREEN : (kind < 0 ? (_currentDamage < 0 ? 0x9F84D6 : HTML_RED) : COLOR_LABEL);
            _total.htmlText = _fmt(_strSumLabel(), 14, COLOR_DIM);
            _total.x = 24;
            _total.y = 72;
            _total.visible = true;

            _htmlSumValue.htmlText = _fmtTitle(_fmtNum(current), 16, currentColor);
            _htmlSumValue.x = int(113 - _htmlSumValue.width);
            _htmlSumValue.y = 71;
            _htmlSumValue.visible = true;

            _htmlSumTarget.htmlText = _fmt(" / " + (target > 0 ? _fmtNum(target) : "N/A"), 14, COLOR_LABEL);
            _htmlSumTarget.x = 117;
            _htmlSumTarget.y = 72;
            _htmlSumTarget.visible = true;

            _targetLine.visible = _expanded;
            if (_expanded)
            {
                var milestonePct:Number = Number(MILESTONE_PCTS[nearestIdx]);
                var milestoneDmg:int = _milestoneRequiredDamage(nearestIdx);
                var tempoPct:int = projMark > 0 ? int(Math.ceil(projMark)) : 55;
                if (tempoPct < 55) tempoPct = 55;
                _targetLabel.htmlText =
                    _fmt("\u0422\u0435\u043c\u043f \u0434\u043b\u044f " + tempoPct.toString() + "%", 14, COLOR_DIM);
                _targetLabel.x = 24;
                _targetLabel.y = 105;
                _targetLabel.visible = true;
                _htmlTempoValue1.htmlText = _fmt(target > 0 ? _fmtNum(target) : "N/A", 14, COLOR_LABEL);
                _htmlTempoValue1.x = int(177 - _htmlTempoValue1.width);
                _htmlTempoValue1.y = 105;
                _htmlTempoValue1.visible = true;

                _targetDmg.htmlText =
                    _fmt("\u0422\u0435\u043c\u043f \u0434\u043b\u044f " + milestonePct.toFixed(0) + "%", 14, COLOR_DIM);
                _targetDmg.x = 24;
                _targetDmg.y = 127;
                _targetDmg.visible = true;
                _htmlTempoValue2.htmlText = _fmt(milestoneDmg > 0 ? _fmtNum(milestoneDmg) : "N/A", 14, COLOR_LABEL);
                _htmlTempoValue2.x = int(177 - _htmlTempoValue2.width);
                _htmlTempoValue2.y = 127;
                _htmlTempoValue2.visible = true;
            }
            else
            {
                _targetLabel.visible = false;
                _targetDmg.visible = false;
                if (_htmlTempoValue1) _htmlTempoValue1.visible = false;
                if (_htmlTempoValue2) _htmlTempoValue2.visible = false;
            }
        }

        private function _drawStyle3BattleOutline(expanded:Boolean):void
        {
            if (!_style3Outline) return;
            var g:Graphics = _style3Outline.graphics;
            g.clear();
            var x:Number = 0;
            var y:Number = 0;
            var w:Number = W_HTML;
            var h:Number = expanded ? 164 : 110;
            var r:Number = 9;
            var topSeg:Number = 58;
            var sGap:Number = 5;
            var barY:Number = 58;
            var connLen:Number = 14;
            var connCapH:Number = 22;
            h = expanded ? H_HTML_EXP : H_HTML;

            // кути — товщі в 2 рази
            g.lineStyle(2.1, HTML_FRAME_LIGHT, 0.37, true);
            _style3Corner(g, x, y, r, 0);
            _style3Corner(g, x + w, y, r, 1);
            _style3Corner(g, x, y + h, r, 2);
            _style3Corner(g, x + w, y + h, r, 3);
            // прямі лінії обводки — товщі в 1.5 раза
            g.lineStyle(1.575, HTML_FRAME_LIGHT, 0.37, true);
            g.moveTo(x + r + sGap, y);       g.lineTo(x + topSeg, y);
            g.moveTo(x + w - topSeg, y);     g.lineTo(x + w - r - sGap, y);
            g.lineStyle(1.575, HTML_FRAME_MID, 0.37, true);
            g.moveTo(x + r + sGap, y + h);   g.lineTo(x + w - r - sGap, y + h);
            g.moveTo(x, y + r + sGap);       g.lineTo(x, y + h - r - sGap);
            g.moveTo(x + w, y + r + sGap);   g.lineTo(x + w, y + h - r - sGap);

            g.lineStyle(1.5, HTML_FRAME_DARK, 0.37, true);
            g.moveTo(x, barY - connCapH / 2);     g.lineTo(x, barY + connCapH / 2);
            g.moveTo(x, barY);                     g.lineTo(x + connLen, barY);
            g.moveTo(x + w, barY - connCapH / 2); g.lineTo(x + w, barY + connCapH / 2);
            g.moveTo(x + w, barY);                 g.lineTo(x + w - connLen, barY);
            g.lineStyle(NaN);
        }

        private function _drawStyle3DetailLine(expanded:Boolean):void
        {
            var g:Graphics = _targetLine.graphics;
            g.clear();
            if (!expanded) return;
            g.lineStyle(1.0, HTML_FRAME_COLOR, 0.34, true);
            g.moveTo(24, 99);
            g.lineTo(174, 99);
            g.lineStyle(NaN);
        }

        private function _drawStyle3BattleFrame(g:Graphics, expanded:Boolean):void
        {
            g.lineStyle(NaN);
        }

        private function _setPanelContentVisible(value:Boolean):void
        {
            if (_bg) _bg.visible = value;
            if (_style3Outline) _style3Outline.visible = value;
            if (_line) _line.visible = value;
            if (_targetLine) _targetLine.visible = value;
            if (_stars) _stars.visible = value;
            if (_arrow) _arrow.visible = value;
            if (_value) _value.visible = value;
            if (_total) _total.visible = value;
            if (_targetLabel) _targetLabel.visible = value;
            if (_targetDmg) _targetDmg.visible = value;
            if (_delta) _delta.visible = value;
            if (_htmlSumValue) _htmlSumValue.visible = value;
            if (_htmlSumTarget) _htmlSumTarget.visible = value;
            if (_htmlTempoValue1) _htmlTempoValue1.visible = value;
            if (_htmlTempoValue2) _htmlTempoValue2.visible = value;
            // окремі рендери — ховаємо лише той, що активний для поточного стилю
            if (_neerRenderer && _style == STYLE_NEER) _neerRenderer.visible = value;
            if (_minimalRenderer && _style == STYLE_MINIMAL) _minimalRenderer.visible = value;
        }

        private function _drawCollapseButton():void
        {
            if (!_collapseBtn) return;
            if (_panelCollapsed)
                _setPanelContentVisible(false);

            _redrawDragHit();
            // кнопка −/+ доступна у ВСІХ стилях (не тільки polaroid)
            _collapseBtn.visible = _controlVisible;
            var g:Graphics = _collapseBtn.graphics;
            g.clear();
            if (!_collapseBtn.visible) return;

            // позиція справа від панелі поточного стилю, на однаковій відстані
            var panelW:Number = _curW();
            var bx:Number = panelW + 12;
            var by:Number = 3;
            var s:Number = 19;
            _collapseBtn.x = bx;
            _collapseBtn.y = by;

            g.beginFill(0x141A22, 0.50);
            g.drawRect(0, 0, s, s);
            g.endFill();
            g.lineStyle(1.0, HTML_FRAME_COLOR, 0.45, true);
            g.drawRect(0.5, 0.5, s - 1, s - 1);

            g.lineStyle(1.5, COLOR_LABEL, 1.0, true);
            g.moveTo(4, s * 0.5);
            g.lineTo(s - 4, s * 0.5);
            if (_panelCollapsed)
            {
                g.moveTo(s * 0.5, 4);
                g.lineTo(s * 0.5, s - 4);
            }
            g.lineStyle(NaN);
        }

        private function _redrawDragHit():void
        {
            if (!_dragHit) return;
            var g:Graphics = _dragHit.graphics;
            g.clear();
            _dragHit.visible = !_panelCollapsed;
            if (!_dragHit.visible) return;

            g.beginFill(0x000000, 0.001);
            g.drawRect(0, 0, _curW(), _curH());
            g.endFill();
        }

        private function _style3Corner(g:Graphics, x:Number, y:Number, r:Number, pos:int):void
        {
            if (pos == 0)
            {
                g.moveTo(x, y + r);
                g.curveTo(x, y, x + r, y);
            }
            else if (pos == 1)
            {
                g.moveTo(x - r, y);
                g.curveTo(x, y, x, y + r);
            }
            else if (pos == 2)
            {
                g.moveTo(x + r, y);
                g.curveTo(x, y, x, y - r);
            }
            else
            {
                g.moveTo(x, y - r);
                g.curveTo(x, y, x - r, y);
            }
        }

        private function _setStyle3AssetsVisible(value:Boolean):void
        {
        }

        private function _drawCompact():void
        {
            var h:int = _expanded ? H_EXP : H;
            var g:Graphics = _bg.graphics;
            g.clear();
            // без рамки — тільки підтемнення фону, щоб текст не губився
            g.lineStyle(NaN);
            g.beginFill(0x0A0E14, 0.18);
            g.drawRoundRect(0, 0, W, h, 8, 8);
            g.endFill();

            // обчислення (ті самі, що в classic)
            var current:int     = _currentDamage >= 0 ? _currentDamage : 0;
            var projAvg:int     = _projectedAvg > 0 ? _projectedAvg : _projectedAverage(current);
            var projMark:Number = _projectedMark >= 0.0 ? _projectedMark :
                                  (projAvg > 0 ? _estimateMarkFromDamage(projAvg) : _mark);
            var delta:Number    = projMark - _mark;
            var kind:int        = Math.abs(delta) < 0.005 ? 0 : (delta > 0 ? 1 : -1);

            var filled:int = _starsCount >= 0 ? _starsCount : 0;

            // ── колонка 1: зірки (знизу вгору) з обводкою ──
            var sg:Graphics = _stars.graphics;
            sg.clear();
            var starX:int = 14;
            var starTopY:int = 20;
            var starGap:int = 20;
            var i:int;
            for (i = 0; i < 3; i++)
            {
                // знизу вгору: i=0 найнижча заповнюється першою
                var starY:Number = starTopY + (2 - i) * starGap;
                sg.lineStyle(1.0, 0xC9D2DC, i < filled ? 0.85 : 0.5, true);
                sg.beginFill(i < filled ? 0xFFFFFF : 0x27313C, 1.0);
                _starPath(sg, starX, starY, 8, 3.4);
                sg.endFill();
            }
            sg.lineStyle(NaN);

            // ── колонка 2: 3 вертикальні лінії = к-сть міток (знизу вгору) ──
            var lineX:Number = 30;
            var lineTopY:int = 20;
            var lineGap:int = 20;
            var lineW:Number = 3;
            var lineH:Number = 13;
            for (i = 0; i < 3; i++)
            {
                var lineY:Number = lineTopY + (2 - i) * lineGap;
                sg.beginFill(i < filled ? 0xFFFFFF : 0x465060, i < filled ? 1.0 : 0.6);
                sg.drawRect(lineX - lineW / 2, lineY - lineH / 2, lineW, lineH);
                sg.endFill();
            }

            var contentX:int = 44;
            var contentR:int = W - 12;

            // ── діагональна стрілка тренду ──
            _drawTrendArrow(47, 22, kind);

            // ── дельта (13px, читабельна) ──
            var deltaStr:String = (kind == 0) ? "" :
                ((delta > 0 ? "+" : "-") + _fmt2(Math.abs(delta)) + "%");
            if (deltaStr.length > 0)
            {
                _delta.htmlText = _fmt(deltaStr, 13, kind > 0 ? COLOR_GREEN : COLOR_RED);
                _delta.x = 58;
                _delta.y = 20;
                _delta.visible = true;
            }
            else
            {
                _delta.visible = false;
            }

            // ── велике число справа (26px, з захистом від накладання на дельту) ──
            var valStr:String = _fmt2(projMark) + "%";
            var deltaRight:Number = _delta.visible ? (_delta.x + _delta.width) : (contentX + 10);
            var vSize:int = 26;
            _value.htmlText = _fmtBold(valStr, vSize, COLOR_LABEL);
            while (vSize > 22 && (contentR - _value.width) < (deltaRight + 6))
            {
                vSize--;
                _value.htmlText = _fmtBold(valStr, vSize, COLOR_LABEL);
            }
            _value.x = int(contentR - _value.width);
            _value.y = int(34 - vSize * 0.9);

            // ── прогрес-бар: 5 сегментів, заповнення від стартового % ──
            var nearestIdx:int = _nearestMilestone(projMark);
            var nearestDmg:int = _milestoneRequiredDamage(nearestIdx);
            var target:int     = _baseDamage > 0 ? _baseDamage : nearestDmg;
            var startMark:Number = _mark >= 0 ? _mark : 0;
            _drawSegmentBar(_line, startMark / 100.0, kind, contentX, contentR - contentX, 48);

            // ── "Загалом" + "cur / req" (обидва приглушено-білі) ──
            _total.htmlText = _fmt(_fmtNum(current) + " / " +
                              (target > 0 ? _fmtNum(target) : "N/A"), 12, COMPACT_DIM_WHITE);
            _total.x = int(contentR - _total.width);
            _total.y = 66;

            _targetLabel.htmlText = _fmt(_strSumLabel(), 12, COMPACT_DIM_WHITE);
            _targetLabel.x = contentX;
            _targetLabel.y = 66;
            _targetLabel.visible = true;

            // ── expanded (Alt): найближча планка ──
            _targetLine.visible = false;
            if (_expanded)
            {
                var milestoneIdx:int    = _nearestMilestone(projMark);
                var milestonePct:Number = Number(MILESTONE_PCTS[milestoneIdx]);
                var milestoneColor:uint = uint(MILESTONE_COLORS[milestoneIdx]);
                var milestoneDmg:int    = _milestoneRequiredDamage(milestoneIdx);
                var pctStr:String = milestonePct.toFixed(0) + "%";
                var dmgStr:String = _fmtNum(milestoneDmg);
                _targetDmg.htmlText = _fmt(pctStr + "  " + dmgStr, 15, milestoneColor);
                _targetDmg.x = int(W / 2 - _targetDmg.width / 2);
                _targetDmg.y = 95;
                _targetDmg.visible = true;
            }
            else
            {
                _targetDmg.visible = false;
            }
        }

        // ── NEER (style 3): золотий танк, заливка по % (розміри як polaroid) ──
        private function _drawNeerStyle():void
        {
            // ховаємо текстові поля основних стилів — neer малює власні
            _value.visible = false;
            _delta.visible = false;
            _total.visible = false;
            _targetLabel.visible = false;
            _targetDmg.visible = false;
            _stars.graphics.clear();
            _line.graphics.clear();
            _arrow.graphics.clear();
            _bg.graphics.clear();
            if (_style3Outline) _style3Outline.graphics.clear();
            if (_targetLine) _targetLine.graphics.clear();

            var current:int     = _currentDamage >= 0 ? _currentDamage : 0;
            var projAvg:int     = _projectedAvg > 0 ? _projectedAvg : _projectedAverage(current);
            var projMark:Number = _projectedMark >= 0.0 ? _projectedMark :
                                  (projAvg > 0 ? _estimateMarkFromDamage(projAvg) : _mark);
            var delta:Number    = projMark - _mark;
            var filled:int      = _starsCount >= 0 ? _starsCount : 0;

            if (_neerRenderer == null)
            {
                _neerRenderer = new MasteryNeerRenderer();
                // neer canvas 406x260 → масштаб ×2 від classic-ширини для більшого вигляду
                var neerScale:Number = (W / 406.0) * 2.0;
                _neerRenderer.scaleX = neerScale;
                _neerRenderer.scaleY = neerScale;
                addChild(_neerRenderer);
            }
            _neerRenderer.visible = true;
            _neerRenderer.render(projMark, delta, filled);
        }

        // ── MINIMAL (style 4): простий текст ─────────────────────────────────
        private function _drawMinimalStyle():void
        {
            _value.visible = false;
            _delta.visible = false;
            _total.visible = false;
            _targetLabel.visible = false;
            _targetDmg.visible = false;
            _stars.graphics.clear();
            _line.graphics.clear();
            _arrow.graphics.clear();
            _bg.graphics.clear();
            if (_style3Outline) _style3Outline.graphics.clear();

            var current:int     = _currentDamage >= 0 ? _currentDamage : 0;
            var projAvg:int     = _projectedAvg > 0 ? _projectedAvg : _projectedAverage(current);
            var projMark:Number = _projectedMark >= 0.0 ? _projectedMark :
                                  (projAvg > 0 ? _estimateMarkFromDamage(projAvg) : _mark);
            var delta:Number    = projMark - _mark;

            // урон щоб вийти в 0 по дельті = baseDamage (скільки треба тримати)
            var zeroDmg:int = _baseDamage > 0 ? _baseDamage : 0;

            // прогноз при delta=0 (де опинишся) і його урон
            var proj0Pct:Number = projMark;
            var proj0Dmg:int    = projAvg;

            // наступна ціль = прогноз +1%
            var nextPct:Number = projMark + 1.0;
            var nextIdx:int    = _nearestMilestone(nextPct);
            var nextDmg:int    = _milestoneRequiredDamage(nextIdx);

            if (_minimalRenderer == null)
            {
                _minimalRenderer = new MasteryMinRenderer();
                addChild(_minimalRenderer);
            }
            _minimalRenderer.visible = true;
            _minimalRenderer.render(projMark, delta, current, zeroDmg, _expanded,
                                    proj0Pct, proj0Dmg, nextPct, nextDmg);
        }

        /** Прогрес-бар з 5 сегментів, заповнення зліва направо за pct (0..1). */
        private function _drawSegmentBar(shape:Shape, pct:Number, kind:int,
                                         x0:Number, w:Number, yPos:Number):void
        {
            var g:Graphics = shape.graphics;
            g.clear();
            var segs:int    = 5;
            var gap:Number  = 2;
            var barH:Number = 4;
            var segW:Number = (w - (segs - 1) * gap) / segs;
            var fillCol:uint = kind >= 0 ? 0x9BD64B : 0xC51917;
            var filledLen:Number = w * Math.max(0.0, Math.min(1.0, pct));
            for (var i:int = 0; i < segs; i++)
            {
                var segX:Number   = x0 + i * (segW + gap);
                g.beginFill(0x788491, 0.5);
                g.drawRect(segX, yPos - barH / 2, segW, barH);
                g.endFill();
                var segStart:Number = i * (segW + gap);
                var fillInSeg:Number = Math.max(0.0, Math.min(segW, filledLen - segStart));
                if (fillInSeg > 0)
                {
                    g.beginFill(fillCol, 1.0);
                    g.drawRect(segX, yPos - barH / 2, fillInSeg, barH);
                    g.endFill();
                }
            }
        }

        private function _strSumLabel():String
        {
            return "\u0417\u0430\u0433\u0430\u043b\u043e\u043c";
        }

        /** Тонка діагональна стрілка тренду: kind 1=↗ up(green) -1=↘ down(red) 0=dash */
        private function _drawTrendArrow(cx:Number, cy:Number, kind:int):void
        {
            var g:Graphics = _arrow.graphics;
            g.clear();
            if (kind == 0)
            {
                return;
            }
            var col:uint = _style == 2
                ? (kind > 0 ? HTML_GREEN : HTML_ARROW_RED)
                : (kind > 0 ? ARROW_UP : ARROW_DOWN);
            var sz:Number = 7;
            g.lineStyle(1.8, col, 1.0, true, "normal", CapsStyle.ROUND);
            if (kind > 0)
            {
                g.moveTo(cx, cy + sz);
                g.lineTo(cx, cy - sz);
                g.moveTo(cx - sz * 0.45, cy - sz * 0.45);
                g.lineTo(cx, cy - sz);
                g.lineTo(cx + sz * 0.45, cy - sz * 0.45);
            }
            else
            {
                g.moveTo(cx, cy - sz);
                g.lineTo(cx, cy + sz);
                g.moveTo(cx - sz * 0.45, cy + sz * 0.45);
                g.lineTo(cx, cy + sz);
                g.lineTo(cx + sz * 0.45, cy + sz * 0.45);
            }
            g.lineStyle(NaN);
        }

        /** Квадратний прогрес-бар (без заокруглень). */
        private function _drawProgressBarSquare(shape:Shape, currentDamage:int,
                                                targetDamage:int, delta:Number,
                                                x0:Number, w:Number, yPos:Number,
                                                barH:Number = 6.0,
                                                sideLeft:Number = NaN,
                                                sideRight:Number = NaN):void
        {
            var g:Graphics = shape.graphics;
            g.clear();
            var pct:Number = targetDamage > 0
                ? Math.max(0.0, Math.min(1.0, Number(currentDamage) / Number(targetDamage)))
                : 0.0;
            var color:uint = delta > 0.005 ? COLOR_GREEN :
                             (delta < -0.005 ? COLOR_RED : COLOR_LABEL);
            var top:Number  = yPos - barH / 2;
            var sideH:Number = 18.0;
            var smallW:Number = 0.0;
            var smallH:Number = 8.0;
            var frameSideTicks:Boolean = !isNaN(sideLeft) && !isNaN(sideRight);
            if (isNaN(sideLeft)) sideLeft = x0 - 9.0;
            if (isNaN(sideRight)) sideRight = x0 + w + 9.0;

            g.lineStyle(1.0, FRAME_COLOR, 0.48, true);
            g.moveTo(sideLeft, yPos);
            g.lineTo(x0, yPos);
            g.moveTo(sideLeft, yPos - sideH * 0.5);
            g.lineTo(sideLeft, yPos + sideH * 0.5);
            g.moveTo(x0 + w, yPos);
            g.lineTo(sideRight, yPos);
            g.moveTo(sideRight, yPos - sideH * 0.5);
            g.lineTo(sideRight, yPos + sideH * 0.5);

            if (frameSideTicks)
            {
                g.lineStyle(1.0, FRAME_COLOR, 0.42, true);
                g.moveTo(x0, yPos - smallH * 0.5);
                g.lineTo(x0, yPos + smallH * 0.5);
                g.moveTo(x0 + w, yPos - smallH * 0.5);
                g.lineTo(x0 + w, yPos + smallH * 0.5);
            }

            if (smallW > 0.0)
            {
                g.lineStyle(1.0, FRAME_COLOR, 0.35, true);
                g.moveTo(x0 + smallW, yPos - smallH * 0.5);
                g.lineTo(x0 + smallW, yPos + smallH * 0.5);
                g.moveTo(x0 + w - smallW, yPos - smallH * 0.5);
                g.lineTo(x0 + w - smallW, yPos + smallH * 0.5);
            }

            // track
            g.lineStyle(frameSideTicks ? 1.0 : 1.6, 0x05070A, frameSideTicks ? 0.65 : 1.0);
            if (!frameSideTicks) g.beginFill(0x16202A, 1.0);
            g.drawRect(x0, top, w, barH);
            if (!frameSideTicks) g.endFill();
            g.lineStyle(NaN);

            // fill
            if (pct > 0)
            {
                g.beginFill(color, 1.0);
                g.drawRect(x0, top, w * pct, barH);
                g.endFill();
            }
            var mx:Number = x0 + w * pct;
            g.lineStyle(2.0, 0xFFFFFF, 1.0);
            g.moveTo(mx, yPos - 5.5);
            g.lineTo(mx, yPos + 5.5);
            g.lineStyle(NaN);
        }

        // ── progress bars ────────────────────────────────────────────────────

        /** Bar filling from 0 to targetDamage, showing currentDamage progress.
            Capsule with fixed dark outline + rounded ends + knob. */
        private function _drawForecastMarkBarSquare(shape:Shape, mark:Number, delta:Number,
                                                    x0:Number, w:Number, yPos:Number,
                                                    barH:Number = 6.0,
                                                    sideLeft:Number = NaN,
                                                    sideRight:Number = NaN):void
        {
            var g:Graphics = shape.graphics;
            g.clear();
            var pct:Number = isNaN(mark) ? 0.0 : Math.max(0.0, Math.min(1.0, mark / 100.0));
            var color:uint = delta > 0.005 ? HTML_GREEN :
                             (delta < -0.005 ? HTML_BAR_RED : COLOR_LABEL);
            var top:Number = yPos - barH / 2;
            var sideH:Number = 18.0;
            var smallH:Number = 8.0;
            var frameSideTicks:Boolean = !isNaN(sideLeft) && !isNaN(sideRight);
            if (isNaN(sideLeft)) sideLeft = x0 - 9.0;
            if (isNaN(sideRight)) sideRight = x0 + w + 9.0;

            g.lineStyle(1.0, HTML_FRAME_COLOR, 0.48, true);
            g.moveTo(sideLeft, yPos);
            g.lineTo(x0, yPos);
            g.moveTo(sideLeft, yPos - sideH * 0.5);
            g.lineTo(sideLeft, yPos + sideH * 0.5);
            g.moveTo(x0 + w, yPos);
            g.lineTo(sideRight, yPos);
            g.moveTo(sideRight, yPos - sideH * 0.5);
            g.lineTo(sideRight, yPos + sideH * 0.5);

            if (frameSideTicks)
            {
                g.lineStyle(1.0, HTML_FRAME_COLOR, 0.42, true);
                g.moveTo(x0, yPos - smallH * 0.5);
                g.lineTo(x0, yPos + smallH * 0.5);
                g.moveTo(x0 + w, yPos - smallH * 0.5);
                g.lineTo(x0 + w, yPos + smallH * 0.5);
            }

            // трек бару — ПРОЗОРИЙ (тонка світла лінія, видно фон крізь неї)
            g.beginFill(0xCCCCCC, 0.30);
            g.drawRect(x0, top, w, barH);
            g.endFill();
            g.lineStyle(NaN);

            if (pct > 0)
            {
                g.beginFill(color, 1.0);
                g.drawRect(x0, top, Math.max(1.0, w * pct), barH);
                g.endFill();
            }

            // маркер — тонка біла риска на межі заповнення
            var mx:Number = x0 + w * pct;
            g.beginFill(0xFEFEFE, 1.0);
            g.drawRect(mx - 1.0, yPos - 5.5, 2.0, 11.0);
            g.endFill();

            g.lineStyle(NaN);
        }

        private function _drawRatingProgressBar(shape:Shape, rating:Number,
                                                x0:Number, w:Number, yPos:Number):void
        {
            var rg:Graphics = shape.graphics;
            rg.clear();
            var rpct:Number = Math.max(0.0, Math.min(1.0, rating / 100.0));
            rg.lineStyle(1.2, 0x05070A, 1.0);
            rg.beginFill(0x0F151C, 1.0);
            rg.drawRect(x0, yPos - 1.5, w, 3.0);
            rg.endFill();
            if (rpct > 0)
            {
                rg.lineStyle(NaN);
                rg.beginFill(0xFFFFFF, 0.92);
                rg.drawRect(x0, yPos - 1.0, Math.max(1.0, w * rpct), 2.0);
                rg.endFill();
            }
            rg.lineStyle(1.0, 0xD7CBA4, 0.55);
            rg.moveTo(x0, yPos);
            rg.lineTo(x0 + w, yPos);
            var mx:Number = x0 + w * rpct;
            rg.lineStyle(1.4, 0xFFFFFF, 0.95);
            rg.moveTo(mx, yPos - 6);
            rg.lineTo(mx, yPos + 6);
            rg.lineStyle(NaN);
        }

        private function _drawProgressBar(shape:Shape, currentDamage:int,
                                          targetDamage:int, delta:Number, yPos:Number):void
        {
            var g:Graphics  = shape.graphics;
            g.clear();
            var w:Number    = W - PAD * 2;
            var pct:Number  = targetDamage > 0
                ? Math.max(0.0, Math.min(1.0, Number(currentDamage) / Number(targetDamage)))
                : 0.0;
            var color:uint  = delta >= 0 ? COLOR_GREEN : COLOR_RED;

            var barH:Number = 6.0;
            var x0:Number   = PAD;
            var x1:Number   = PAD + w;
            var top:Number  = yPos - barH / 2;

            // fixed dark outline capsule
            g.lineStyle(1.4, 0x0A0E14, 1.0);
            g.beginFill(0x16202A, 1.0);
            g.drawRoundRect(x0, top, w, barH, barH, barH);
            g.endFill();
            g.lineStyle(NaN);

            // fill
            if (pct > 0)
            {
                g.beginFill(color, 1.0);
                g.drawRoundRect(x0, top, Math.max(barH, w * pct), barH, barH, barH);
                g.endFill();
            }

            // knob
            g.lineStyle(1.4, 0xFFFFFF, 0.92);
            g.beginFill(color, 1.0);
            g.drawCircle(x0 + w * pct, yPos, 4.5);
            g.endFill();
            g.lineStyle(NaN);
        }

        /** Delta direction arrow: kind 1=up(green) -1=down(red) 0=zero(white dash) */
        private function _drawArrow(cx:Number, cy:Number, kind:int):void
        {
            var g:Graphics = _arrow.graphics;
            g.clear();
            if (kind == 1)
            {
                g.lineStyle(1.4, ARROW_UP, 1.0);
                g.moveTo(cx, cy + 6);  g.lineTo(cx, cy - 3);
                g.lineStyle(NaN);
                g.beginFill(ARROW_UP, 1.0);
                g.moveTo(cx, cy - 7);  g.lineTo(cx - 4, cy - 2);  g.lineTo(cx + 4, cy - 2);
                g.lineTo(cx, cy - 7);
                g.endFill();
            }
            else if (kind == -1)
            {
                g.lineStyle(1.4, ARROW_DOWN, 1.0);
                g.moveTo(cx, cy - 6);  g.lineTo(cx, cy + 3);
                g.lineStyle(NaN);
                g.beginFill(ARROW_DOWN, 1.0);
                g.moveTo(cx, cy + 7);  g.lineTo(cx - 4, cy + 2);  g.lineTo(cx + 4, cy + 2);
                g.lineTo(cx, cy + 7);
                g.endFill();
            }
            else
            {
                g.lineStyle(1.6, ARROW_ZERO, 1.0);
                g.moveTo(cx - 4, cy);  g.lineTo(cx + 4, cy);
                g.lineStyle(NaN);
            }
        }

        private function _drawFrameSegments(g:Graphics, w:Number, h:Number, barY:Number):void
        {
            var inset:Number   = 3.0;
            var rad:Number     = 14;
            var lineColor:uint = 0xC9D2DC;
            var a:Number       = 0.88;
            var x0:Number = inset, y0:Number = inset, x1:Number = w - inset, y1:Number = h - inset;

            g.lineStyle(0.9, lineColor, a, true);

            // ── кутові дуги ──
            _arcSeg(g, x0 + rad, y0 + rad, rad, 180, 270);
            _arcSeg(g, x1 - rad, y0 + rad, rad, 270, 360);
            _arcSeg(g, x0 + rad, y1 - rad, rad,  90, 180);
            _arcSeg(g, x1 - rad, y1 - rad, rad,   0,  90);

            var tl:Number = x0 + rad, tr:Number = x1 - rad;

            // ── верх: розрив посередині (де зірки/число) ──
            var gc0:Number = tl + (tr - tl) * 0.28;
            var gc1:Number = tl + (tr - tl) * 0.70;
            g.moveTo(tl, y0);  g.lineTo(gc0, y0);
            g.moveTo(gc1, y0); g.lineTo(tr, y0);

            // ── низ: суцільний ──
            g.moveTo(tl, y1); g.lineTo(tr, y1);

            // ── боки: короткі розрізи (4 на кожен) ──
            var ftop:Number = y0 + rad, fbot:Number = y1 - rad, fh:Number = fbot - ftop;
            var gaps:Array = [0.13, 0.34, 0.62, 0.90];
            var gw:Number  = 0.07;
            _sideEdge(g, x0, ftop, fbot, fh, gaps, gw);
            _sideEdge(g, x1, ftop, fbot, fh, gaps, gw);

            // ── бічні конектори: від краю рамки до бара (короткі, половина) ──
            g.moveTo(x0, barY);                  g.lineTo((x0 + PAD - 3) / 2, barY);
            g.moveTo((x1 + w - PAD + 3) / 2, barY); g.lineTo(x1, barY);

            g.lineStyle(NaN);
        }

        /** Рамка для compact-стилю: верх суцільний (контент не по центру),
            конектори до бару відрізають ліву зону зірок/смужок. */
        private function _drawFrameSegmentsCompact(g:Graphics, w:Number, h:Number, barY:Number):void
        {
            var inset:Number   = 3.0;
            var rad:Number     = 6;
            var lineColor:uint = 0xC9D2DC;
            var a:Number       = 0.46;
            var x0:Number = inset, y0:Number = inset, x1:Number = w - inset, y1:Number = h - inset;

            g.lineStyle(0.9, lineColor, a, true);

            // кутові дуги
            _arcSeg(g, x0 + rad, y0 + rad, rad, 180, 270);
            _arcSeg(g, x1 - rad, y0 + rad, rad, 270, 360);
            _arcSeg(g, x0 + rad, y1 - rad, rad,  90, 180);
            _arcSeg(g, x1 - rad, y1 - rad, rad,   0,  90);

            var tl:Number = x0 + rad, tr:Number = x1 - rad;

            // верх: суцільний (без центрального розриву)
            g.moveTo(tl, y0); g.lineTo(tr, y0);
            // низ: суцільний
            g.moveTo(tl, y1); g.lineTo(tr, y1);

            // боки: короткі розрізи
            var ftop:Number = y0 + rad, fbot:Number = y1 - rad, fh:Number = fbot - ftop;
            var gaps:Array = [0.10, 0.46, 0.66, 0.89];
            var gw:Number  = 0.05;
            _sideEdge(g, x0, ftop, fbot, fh, gaps, gw);
            _sideEdge(g, x1, ftop, fbot, fh, gaps, gw);

            g.lineStyle(NaN);
        }

        private function _arcSeg(g:Graphics, cx:Number, cy:Number, r:Number,
                                 startDeg:Number, endDeg:Number):void
        {
            var steps:int = 8;
            var a0:Number = startDeg * Math.PI / 180.0;
            var a1:Number = endDeg   * Math.PI / 180.0;
            g.moveTo(cx + Math.cos(a0) * r, cy + Math.sin(a0) * r);
            for (var i:int = 1; i <= steps; i++)
            {
                var t:Number = a0 + (a1 - a0) * (i / Number(steps));
                g.lineTo(cx + Math.cos(t) * r, cy + Math.sin(t) * r);
            }
        }

        private function _sideEdge(g:Graphics, x:Number, ftop:Number, fbot:Number,
                                   fh:Number, gaps:Array, gw:Number):void
        {
            var prev:Number = ftop;
            for (var i:int = 0; i < gaps.length; i++)
            {
                var gy:Number = ftop + fh * Number(gaps[i]);
                g.moveTo(x, prev);  g.lineTo(x, gy - fh * gw / 2);
                prev = gy + fh * gw / 2;
            }
            g.moveTo(x, prev);  g.lineTo(x, fbot);
        }

        /** Milestone bar: shows progress from 0 to milestonePct */
        private function _drawMilestoneBar(shape:Shape, projMark:Number,
                                           milestonePct:Number, milestoneColor:uint, yPos:Number):void
        {
            var g:Graphics = shape.graphics;
            g.clear();
            var w:Number   = W - PAD * 2;

            // track
            g.lineStyle(5, 0x2A2F35, 1.0);
            g.moveTo(PAD, yPos);  g.lineTo(PAD + w, yPos);

            // fill up to current projected mark (capped at milestone)
            var fillPct:Number = Math.max(0.0, Math.min(milestonePct, projMark)) / milestonePct;
            var fillColor:uint = projMark >= milestonePct ? 0x8ED05A : milestoneColor;
            g.lineStyle(5, fillColor, 1.0);
            g.moveTo(PAD, yPos);  g.lineTo(PAD + w * fillPct, yPos);

            // milestone end marker (right edge = goal)
            g.lineStyle(2, milestoneColor, 1.0);
            g.moveTo(PAD + w, yPos - 6);
            g.lineTo(PAD + w, yPos + 6);

            // knob at current position
            if (projMark < milestonePct)
            {
                g.lineStyle(1, 0xFFFFFF, 0.85);
                g.beginFill(fillColor, 1.0);
                g.drawCircle(PAD + w * fillPct, yPos, 4.0);
                g.endFill();
            }
            else
            {
                // checkmark circle
                g.lineStyle(1.5, 0x8ED05A, 1.0);
                g.beginFill(0x8ED05A, 0.25);
                g.drawCircle(PAD + w, yPos, 5.0);
                g.endFill();
            }
            g.lineStyle(NaN);
        }

        // ── milestone helpers ─────────────────────────────────────────────────

        /** Returns index 0/1/2 of nearest milestone ≥ projMark (clamps to last) */
        private function _nearestMilestone(projMark:Number):int
        {
            for (var i:int = 0; i < MILESTONE_PCTS.length; i++)
            {
                if (projMark < Number(MILESTONE_PCTS[i]))
                    return i;
            }
            return MILESTONE_PCTS.length - 1; // already at/above 95% → show 95% bar
        }

        /** Required damage for milestone index */
        private function _milestoneRequiredDamage(idx:int):int
        {
            if (idx == 0) return _p65;
            if (idx == 1) return _p85;
            return _p95;
        }

        // ── math helpers ──────────────────────────────────────────────────────

        private static const MOE_CALC_KOEFF:Number = 2.0 / 101.0;

        private function _projectedAverage(currentDamage:int):int
        {
            if (_baseDamage <= 0) return 0;
            return int(Math.round(
                Number(_baseDamage) * (1.0 - MOE_CALC_KOEFF) + Number(currentDamage) * MOE_CALC_KOEFF
            ));
        }

        private function _estimateMarkFromDamage(damage:int):Number
        {
            var points:Array = [
                { pct: 65.0,  val: Number(_p65)  },
                { pct: 85.0,  val: Number(_p85)  },
                { pct: 95.0,  val: Number(_p95)  },
                { pct: 100.0, val: Number(_p100) }
            ];
            var prevPct:Number = 0.0, prevVal:Number = 0.0;
            for (var i:int = 0; i < points.length; i++)
            {
                var np:Number = Number(points[i].pct), nv:Number = Number(points[i].val);
                if (nv <= 0) continue;
                if (damage <= nv)
                {
                    var span:Number = nv - prevVal;
                    if (span <= 0) return np;
                    var t:Number = Math.max(0.0, Math.min(1.0, (Number(damage) - prevVal) / span));
                    return prevPct + (np - prevPct) * t;
                }
                prevPct = np;  prevVal = nv;
            }
            return prevPct;
        }

        // ── stars ─────────────────────────────────────────────────────────────

        private function _drawStars(markValue:Number):void
        {
            var g:Graphics = _stars.graphics;
            g.clear();
            var filled:int = _starsCount >= 0 ? _starsCount : 0;
            // Зірки по центру, більші, з обводкою як у рамки (щоб не губились)
            var starSpacing:int = 22;
            var starTotalW:int  = 3 * starSpacing;
            var starStartX:int  = int(W / 2 - starTotalW / 2 + starSpacing / 2);
            for (var i:int = 0; i < 3; i++)
            {
                g.lineStyle(1.0, 0xC9D2DC, i < filled ? 0.9 : 0.55, true);
                g.beginFill(i < filled ? 0xFFFFFF : 0x27313C, 1.0);
                _starPath(g, starStartX + i * starSpacing, 6, 8, 3.4);
                g.endFill();
            }
            g.lineStyle(NaN);
        }

        // ── text / util ───────────────────────────────────────────────────────

        private function _makeText(size:int, color:uint):TextField
        {
            var tf:TextField = new TextField();
            tf.selectable  = false;
            tf.mouseEnabled = false;
            tf.autoSize    = TextFieldAutoSize.LEFT;
            tf.multiline   = false;
            tf.antiAliasType = AntiAliasType.ADVANCED;
            tf.gridFitType = GridFitType.PIXEL;
            tf.sharpness = 0;
            tf.thickness = 0;
            tf.filters     = [new GlowFilter(0x000000, 1.0, 4, 4, 4, 1), _shadow];
            tf.htmlText    = _fmt("", size, color);
            return tf;
        }

        private function _setTextFilters(style3:Boolean):void
        {
            var sx:Number = 1.0;
            _value.scaleX = sx;
            _total.scaleX = sx;
            _targetLabel.scaleX = sx;
            _targetDmg.scaleX = sx;
            _delta.scaleX = sx;
            if (_htmlSumValue) _htmlSumValue.scaleX = sx;
            if (_htmlSumTarget) _htmlSumTarget.scaleX = sx;
            if (_htmlTempoValue1) _htmlTempoValue1.scaleX = sx;
            if (_htmlTempoValue2) _htmlTempoValue2.scaleX = sx;
            // polaroid: слабший чорний glow — сильний гасив кольори (робив їх тьмяними)
            var filters:Array = style3
                ? [new GlowFilter(0x000000, 0.55, 2, 2, 1.4, 1)]
                : [new GlowFilter(0x000000, 1.0, 4, 4, 4, 1), _shadow];
            _value.filters = filters;
            _total.filters = filters;
            _targetLabel.filters = filters;
            _targetDmg.filters = filters;
            _delta.filters = filters;
            if (_htmlSumValue) _htmlSumValue.filters = filters;
            if (_htmlSumTarget) _htmlSumTarget.filters = filters;
            if (_htmlTempoValue1) _htmlTempoValue1.filters = filters;
            if (_htmlTempoValue2) _htmlTempoValue2.filters = filters;
        }

        private function _starPath(g:Graphics, cx:Number, cy:Number, r1:Number, r2:Number):void
        {
            var a:Number    = -Math.PI / 2;
            var step:Number = Math.PI / 5;
            g.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
            for (var i:int = 1; i <= 10; i++)
            {
                a += step;
                var r:Number = (i % 2 == 0) ? r1 : r2;
                g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
            }
        }

        private function _fmtBold(text:String, size:int, color:uint):String
        {
            var hex:String = color.toString(16);
            while (hex.length < 6) hex = "0" + hex;
            return "<font face='" + FONT_FACE + "' size='" + size + "' color='#" + hex + "'><b>" + text + "</b></font>";
        }

        private function _fmtTitle(text:String, size:int, color:uint):String
        {
            var hex:String = color.toString(16);
            while (hex.length < 6) hex = "0" + hex;
            return "<font face='" + TITLE_FONT_FACE + "' size='" + size + "' color='#" + hex + "'>" + text + "</font>";
        }

        private function _fmt(text:String, size:int, color:uint):String
        {
            var hex:String = color.toString(16);
            while (hex.length < 6) hex = "0" + hex;
            return "<font face='" + FONT_FACE + "' size='" + size + "' color='#" + hex + "'>" + text + "</font>";
        }

        private function _fmt2(value:Number):String
        {
            return (isNaN(value) ? 0.0 : value).toFixed(2);
        }

        private function _fmtNum(value:int):String
        {
            var s:String = Math.abs(value).toString();
            var out:String = "";
            while (s.length > 3) { out = " " + s.substr(s.length - 3) + out; s = s.substr(0, s.length - 3); }
            out = s + out;
            return value < 0 ? "-" + out : out;
        }
    }
}
