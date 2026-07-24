package com.under_pressure.mastery
{
    import flash.display.DisplayObjectContainer;
    import flash.display.MovieClip;
    import flash.events.Event;
    import flash.geom.Point;
    import flash.utils.getQualifiedClassName;
    import net.wg.infrastructure.base.AbstractView;
    import net.wg.infrastructure.events.LoaderEvent;
    import net.wg.infrastructure.managers.impl.ContainerManagerBase;

    public class MasteryPanelInjector extends AbstractView
    {
        private var _panel:MasteryPanelComponent = null;
        private var _detail:MasteryDetailPanel   = null;
        private var _battleBadge:MasteryBattleMarkBadge = null;
        private var _resultBadge:MasteryBattleResultBadge = null;
        private var _resultHost:DisplayObjectContainer = null;

        public var py_onDragEnd:Function          = null;
        public var py_onPanelReady:Function       = null;
        public var py_onViewModeChanged:Function  = null;
        public var py_onExpandToggle:Function     = null;
        public var py_onMarkBadgeToggle:Function  = null;
        public var py_onMarkBadgeOffsetChanged:Function = null;
        public var py_onBattleBadgeOffsetChanged:Function = null;

        private var _configDone:Boolean    = false;
        private var _pendingCalls:Array    = [];
        private var _notifyFrameCount:int  = 0;
        private var _strBattleResultProgress:String = "Marks";

        public function MasteryPanelInjector()
        {
            super();
        }

        override protected function configUI():void
        {
            super.configUI();

            _createPanel();
            _configDone = true;
            _replayPendingCalls();

            var cm:ContainerManagerBase = App.containerMgr as ContainerManagerBase;
            if (cm && cm.loader)
                cm.loader.addEventListener(LoaderEvent.VIEW_LOADED, _onViewLoaded);

            if (App.instance && App.instance.stage)
                App.instance.stage.addEventListener(Event.RESIZE, _onResize);

            _notifyFrameCount = 0;
            addEventListener(Event.ENTER_FRAME, _onNotifyFrame);
        }

        override protected function nextFrameAfterPopulateHandler():void
        {
            super.nextFrameAfterPopulateHandler();
            // FIX: оригінал переміщав this до App.instance через addChild —
            // але це змінювало батька і ламало координатну систему дочірніх компонентів.
            // _bringToFront() безпечніший — не змінює батька, просто переміщає вгору стеку.
            _bringToFront();
        }

        override protected function onDispose():void
        {
            removeEventListener(Event.ENTER_FRAME, _onNotifyFrame);
            var cm:ContainerManagerBase = App.containerMgr as ContainerManagerBase;
            if (cm && cm.loader)
                cm.loader.removeEventListener(LoaderEvent.VIEW_LOADED, _onViewLoaded);
            if (App.instance && App.instance.stage)
                App.instance.stage.removeEventListener(Event.RESIZE, _onResize);
            _destroyPanel();
            _pendingCalls = [];
            py_onDragEnd         = null;
            py_onPanelReady      = null;
            py_onViewModeChanged = null;
            py_onExpandToggle    = null;
            py_onMarkBadgeToggle = null;
            py_onMarkBadgeOffsetChanged = null;
            py_onBattleBadgeOffsetChanged = null;
            _configDone = false;
            super.onDispose();
        }

        private function _onNotifyFrame(event:Event):void
        {
            _notifyFrameCount++;
            // FIX: збільшено з 3 до 5 кадрів — після видалення reparent логіки
            // панелі потрібно більше часу для стабілізації layout перед py_onPanelReady
            if (_notifyFrameCount < 5) return;
            removeEventListener(Event.ENTER_FRAME, _onNotifyFrame);
            if (py_onPanelReady != null)
                py_onPanelReady();
        }

        private function _onResize(event:Event):void
        {
            if (_panel) _panel.updatePosition();
            if (_detail) _detail.updateLayout();
            _layoutBattleBadge();
            _layoutResultBadge();
        }

        private function _onViewLoaded(event:LoaderEvent):void
        {
            if (_isBattleResultsEvent(event))
            {
                _resultHost = _extractViewContainer(event);
                _attachResultBadgeToHost();
            }
            else if (_isGarageEvent(event))
            {
                _hideResultBadge();
                _resultHost = null;
                _attachResultBadgeToHost();
            }
            _bringToFront();
            if (_panel) _panel.updatePosition();
            if (_detail) _detail.updateLayout();
            _layoutResultBadge();
        }

        private function _createPanel():void
        {
            if (_panel) return;
            _panel = new MasteryPanelComponent();
            _panel.addEventListener(MasteryPanelEvent.OFFSET_CHANGED,    _onOffsetChanged);
            _panel.addEventListener(MasteryPanelEvent.VIEW_MODE_CHANGED, _onViewModeChanged);
            _panel.addEventListener(MasteryPanelEvent.EXPAND_TOGGLE,     _onExpandToggle);
            _panel.addEventListener(MasteryPanelEvent.MARK_BADGE_TOGGLE, _onMarkBadgeToggle);
            _panel.addEventListener(MasteryPanelEvent.MARK_BADGE_OFFSET_CHANGED, _onMarkBadgeOffsetChanged);
            _panel.setVisibleState(false);
            addChild(_panel);

            _detail = new MasteryDetailPanel();
            _detail.addEventListener(MasteryPanelEvent.EXPAND_TOGGLE, _onExpandToggle);
            addChild(_detail);

            _battleBadge = new MasteryBattleMarkBadge();
            _battleBadge.addEventListener(MasteryPanelEvent.BATTLE_BADGE_OFFSET_CHANGED, _onBattleBadgeOffsetChanged);
            _battleBadge.visible = false;
            addChild(_battleBadge);
            _layoutBattleBadge();

            _createResultBadge();
        }

        private function _destroyPanel():void
        {
            if (_panel)
            {
                _panel.removeEventListener(MasteryPanelEvent.OFFSET_CHANGED,    _onOffsetChanged);
                _panel.removeEventListener(MasteryPanelEvent.VIEW_MODE_CHANGED, _onViewModeChanged);
                _panel.removeEventListener(MasteryPanelEvent.EXPAND_TOGGLE,     _onExpandToggle);
                _panel.removeEventListener(MasteryPanelEvent.MARK_BADGE_TOGGLE, _onMarkBadgeToggle);
                _panel.removeEventListener(MasteryPanelEvent.MARK_BADGE_OFFSET_CHANGED, _onMarkBadgeOffsetChanged);
                _panel.dispose();
                if (_panel.parent) _panel.parent.removeChild(_panel);
                _panel = null;
            }
            if (_detail)
            {
                _detail.removeEventListener(MasteryPanelEvent.EXPAND_TOGGLE, _onExpandToggle);
                _detail.dispose();
                if (_detail.parent) _detail.parent.removeChild(_detail);
                _detail = null;
            }
            if (_battleBadge)
            {
                _battleBadge.removeEventListener(MasteryPanelEvent.BATTLE_BADGE_OFFSET_CHANGED, _onBattleBadgeOffsetChanged);
                _battleBadge.dispose();
                if (_battleBadge.parent) _battleBadge.parent.removeChild(_battleBadge);
                _battleBadge = null;
            }
            if (_resultBadge)
            {
                if (_resultBadge.parent) _resultBadge.parent.removeChild(_resultBadge);
                _resultBadge = null;
                _resultHost = null;
            }
        }

        private function _createResultBadge():void
        {
            if (_resultBadge) return;
            _resultBadge = new MasteryBattleResultBadge();
            _resultBadge.visible = false;
            _attachResultBadgeToHost();
        }

        private function _attachResultBadgeToHost():void
        {
            if (!_resultBadge) return;
            // FIX: завжди тримаємо _resultBadge як дочірній до this (Injector),
            // а не до _resultHost. Переміщення між батьками скидає координати.
            // Позиція рахується в _layoutResultBadge через stage координати.
            if (_resultBadge.parent != this)
                addChild(_resultBadge);
            _bringResultBadgeToFront();
        }

        private function _showResultBadge(currentMark:Number, delta:Number):void
        {
            if (!_resultBadge) _createResultBadge();
            if (!_resultBadge) return;

            _resultBadge.setTitle(_strBattleResultProgress);
            _resultBadge.setData(currentMark, delta);
            _attachResultBadgeToHost();
            _bringResultBadgeToFront();
            _layoutResultBadge();

        }

        private function _hideResultBadge():void
        {
            if (_resultBadge) _resultBadge.visible = false;
        }

        private function _layoutBattleBadge():void
        {
            if (!_battleBadge) return;
            _battleBadge.updatePosition();
        }

        private function _layoutResultBadge():void
        {
            if (!_resultBadge) return;
            // FIX: оригінал рахував позицію відносно _resultHost.width/height,
            // але _resultHost може мати width=0 до завантаження → badge вилітав за екран.
            // Завжди рахуємо відносно stage — це глобальні координати екрану.
            // globalToLocal() конвертує в локальні координати батька badge.
            var sw:int = (stage != null && stage.stageWidth  > 0) ? stage.stageWidth  : 1280;
            var sh:int = (stage != null && stage.stageHeight > 0) ? stage.stageHeight : 720;
            var globalX:int = int(sw * 0.74);
            var globalY:int = int(sh - _resultBadge.height - 118);
            // Конвертуємо глобальні координати в локальні батька
            if (_resultBadge.parent != null && _resultBadge.parent != this)
            {
                try
                {
                    var localPt:flash.geom.Point = _resultBadge.parent.globalToLocal(
                        new flash.geom.Point(globalX, globalY));
                    _resultBadge.x = int(localPt.x);
                    _resultBadge.y = int(localPt.y);
                    return;
                }
                catch (e:Error) {}
            }
            _resultBadge.x = globalX;
            _resultBadge.y = globalY;
        }

        private function _extractViewContainer(event:LoaderEvent):DisplayObjectContainer
        {
            var eventObj:Object = event as Object;
            var keys:Array = ["view", "content", "viewComponent"];
            for (var i:int = 0; i < keys.length; i++)
            {
                var candidate:Object = _dyn(eventObj, keys[i]);
                if (candidate is DisplayObjectContainer)
                    return candidate as DisplayObjectContainer;
            }
            return null;
        }

        private function _isBattleResultsEvent(event:LoaderEvent):Boolean
        {
            var text:String = _eventText(event);
            return text.indexOf("battleresult") >= 0 ||
                   (text.indexOf("battle") >= 0 && text.indexOf("result") >= 0);
        }

        private function _isGarageEvent(event:LoaderEvent):Boolean
        {
            var text:String = _eventText(event);
            return text.indexOf("hangar") >= 0 || text.indexOf("garage") >= 0;
        }

        private function _eventText(event:LoaderEvent):String
        {
            var parts:Array = [];
            var eventObj:Object = event as Object;
            _appendText(parts, event);
            _appendViewText(parts, _dyn(eventObj, "view"));
            _appendViewText(parts, _dyn(eventObj, "content"));
            _appendText(parts, _dyn(eventObj, "viewAlias"));
            _appendText(parts, _dyn(eventObj, "alias"));
            _appendText(parts, _dyn(eventObj, "name"));
            return parts.join(" ").toLowerCase();
        }

        private function _appendViewText(parts:Array, value:Object):void
        {
            _appendText(parts, value);
            var loadParams:Object = _dyn(value, "loadParams");
            if (loadParams == null) loadParams = _dyn(value, "_loadParams");
            _appendText(parts, loadParams);
            var viewKey:Object = _dyn(loadParams, "viewKey");
            if (viewKey == null) viewKey = _dyn(loadParams, "_viewKey");
            _appendText(parts, viewKey);
            _appendText(parts, _dyn(viewKey, "alias"));
            _appendText(parts, _dyn(viewKey, "name"));
        }

        private function _appendText(parts:Array, value:Object):void
        {
            if (value == null) return;
            try
            {
                parts.push(String(value));
                parts.push(getQualifiedClassName(value));
            }
            catch (e:Error) {}
        }

        private function _dyn(source:Object, key:String):Object
        {
            if (source == null) return null;
            try
            {
                return source[key];
            }
            catch (e:Error) {}
            return null;
        }

        private function _replayPendingCalls():void
        {
            if (_pendingCalls.length == 0) return;
            var calls:Array = _pendingCalls;
            _pendingCalls = [];
            for (var i:int = 0; i < calls.length; i++)
            {
                var call:Object = calls[i];
                var fn:Function = call.fn as Function;
                if (fn != null) fn.apply(null, call.args);
            }
        }

        private function _onOffsetChanged(event:MasteryPanelEvent):void
        {
            if (py_onDragEnd != null) py_onDragEnd(event.data);
        }

        private function _onViewModeChanged(event:MasteryPanelEvent):void
        {
            if (py_onViewModeChanged != null) py_onViewModeChanged(event.data);
        }

        private function _onExpandToggle(event:MasteryPanelEvent):void
        {
            if (py_onExpandToggle != null) py_onExpandToggle();
        }

        private function _onMarkBadgeToggle(event:MasteryPanelEvent):void
        {
            if (py_onMarkBadgeToggle != null) py_onMarkBadgeToggle(Boolean(event.data));
        }

        private function _onMarkBadgeOffsetChanged(event:MasteryPanelEvent):void
        {
            if (py_onMarkBadgeOffsetChanged != null) py_onMarkBadgeOffsetChanged(event.data);
        }

        private function _onBattleBadgeOffsetChanged(event:MasteryPanelEvent):void
        {
            if (py_onBattleBadgeOffsetChanged != null) py_onBattleBadgeOffsetChanged(event.data);
        }

        // ── AS3 callable from Python ──────────────────────────────────────

        private function _bringToFront():void
        {
            try
            {
                if (parent != null)
                    parent.setChildIndex(this, parent.numChildren - 1);
            }
            catch (e:Error) {}
        }

        private function _bringResultBadgeToFront():void
        {
            try
            {
                if (_resultBadge != null && _resultBadge.parent != null)
                    _resultBadge.parent.setChildIndex(_resultBadge, _resultBadge.parent.numChildren - 1);
            }
            catch (e:Error) {}
        }

        public function as_setMasteryData(third:int, second:int, first:int, ace:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMasteryData, args: [third, second, first, ace]}); return; }
            if (_panel) _panel.setMasteryData(third, second, first, ace);
        }

        public function as_setMoeData(p65:int, p85:int, p95:int, p100:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMoeData, args: [p65, p85, p95, p100]}); return; }
            if (_panel) _panel.setMoeData(p65, p85, p95, p100);
        }

        public function as_setBattleHistory(values:Array, currentMark:Number):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleHistory, args: [values, currentMark]}); return; }
            if (_panel) _panel.setBattleHistory(values, currentMark);
        }

        public function as_setLastBattleDamage(value:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setLastBattleDamage, args: [value]}); return; }
            if (_panel) _panel.setLastBattleDamage(value);
        }

        public function as_setViewMode(mode:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setViewMode, args: [mode]}); return; }
            if (_panel) _panel.setViewMode(mode);
        }

        public function as_setMarkBadgeOpen(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMarkBadgeOpen, args: [value]}); return; }
            if (_panel) _panel.setMarkBadgeOpen(value);
        }

        public function as_setMarkBadgeEnabled(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMarkBadgeEnabled, args: [value]}); return; }
            if (_panel) _panel.setMarkBadgeEnabled(value);
        }

        public function as_setMarkBadgeControlVisible(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMarkBadgeControlVisible, args: [value]}); return; }
            if (_panel) _panel.setMarkBadgeControlVisible(value);
        }

        public function as_setPanelBodyVisible(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setPanelBodyVisible, args: [value]}); return; }
            if (_panel) _panel.setPanelBodyVisible(value);
        }

        public function as_setMarkBadgeOffset(offset:Array):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMarkBadgeOffset, args: [offset]}); return; }
            if (_panel) _panel.setMarkBadgeOffset(offset);
        }

        public function as_setBattleBadgeOffset(offset:Array):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleBadgeOffset, args: [offset]}); return; }
            if (_battleBadge) _battleBadge.setPositionOffset(offset);
        }

        public function as_setMarkBadgeStars(value:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMarkBadgeStars, args: [value]}); return; }
            if (_panel) _panel.setMarkBadgeStars(value);
        }

        public function as_setMarkBadgeStyle(value:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setMarkBadgeStyle, args: [value]}); return; }
            if (_panel) _panel.setMarkBadgeStyle(value);
        }

        public function as_setBattleBadgeStyle(value:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleBadgeStyle, args: [value]}); return; }
            if (_battleBadge) _battleBadge.setStyle(value);
        }

        public function as_setBattleBadgeData(currentMark:Number, p65:int, p85:int, p95:int, p100:int, currentDamage:int, baseDamage:int, stars:int, projectedMark:Number = -1.0, projectedAvg:int = 0):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleBadgeData, args: [currentMark, p65, p85, p95, p100, currentDamage, baseDamage, stars, projectedMark, projectedAvg]}); return; }
            if (_battleBadge) _battleBadge.setData(currentMark, p65, p85, p95, p100, currentDamage, baseDamage, stars, projectedMark, projectedAvg);
        }

        public function as_setBattleBadgeDamage(currentDamage:int):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleBadgeDamage, args: [currentDamage]}); return; }
            if (_battleBadge) _battleBadge.setCurrentDamage(currentDamage);
        }

        public function as_setBattleBadgeExpanded(value:Boolean):void
        {
            if (_battleBadge) _battleBadge.setExpanded(value);
        }

        public function as_setBattleBadgeVisible(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleBadgeVisible, args: [value]}); return; }
            if (_battleBadge)
            {
                _battleBadge.visible = value;
                _layoutBattleBadge();
            }
            // FIX: оригінал: _panel.setVisibleState(!value && _panel.visible)
            // Проблема: коли value=false (сховати badge) і _panel.visible=false
            // → false && false = false → панель НЕ відновлювалась після бою.
            // Виправлення: панель ховаємо тільки при value=true (бій активний).
            // Відновлення панелі — через as_setVisible який Python викликає окремо.
            if (_panel && value)
            {
                _panel.setVisibleState(false);
            }
            if (_detail && value) _detail.hide();
        }

        public function as_setLoading():void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setLoading, args: []}); return; }
            if (_panel) _panel.setLoading();
        }

        public function as_clearData():void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_clearData, args: []}); return; }
            if (_panel) _panel.clearData();
        }

        public function as_setVisible(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setVisible, args: [value]}); return; }
            if (_panel) _panel.setVisibleState(value);
        }

        public function as_setPosition(offset:Array):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setPosition, args: [offset]}); return; }
            if (_panel) _panel.setPositionOffset(offset);
        }

        public function as_setLocalization(data:Object):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setLocalization, args: [data]}); return; }
            if (data && data.battleResultProgress)
            {
                _strBattleResultProgress = String(data.battleResultProgress);
                if (_resultBadge) _resultBadge.setTitle(_strBattleResultProgress);
            }
            if (_panel)  _panel.setLocalization(data);
            if (_detail) _detail.setLocalization(data);
        }

        public function as_showBattleResultProgress(currentMark:Number, delta:Number):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_showBattleResultProgress, args: [currentMark, delta]}); return; }
            _showResultBadge(currentMark, delta);
        }

        public function as_setBattleResultProgressVisible(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setBattleResultProgressVisible, args: [value]}); return; }
            if (!value) _hideResultBadge();
            else if (_resultBadge)
            {
                _attachResultBadgeToHost();
                _resultBadge.visible = true;
                _bringResultBadgeToFront();
                _layoutResultBadge();
            }
        }

        // ── Detail panel API ──────────────────────────────────────────────

        public function as_setDetailTankInfo(tankName:String, flag:String,
                                             stars:int, currentMark:Number):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setDetailTankInfo,
                args: [tankName, flag, stars, currentMark]}); return; }
            if (_detail) _detail.setTankInfo(tankName, flag, stars, currentMark);
        }

        public function as_setDetailBattles(entries:Array):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_setDetailBattles, args: [entries]}); return; }
            if (_detail) _detail.setBattles(entries);
        }

        public function as_showDetail(value:Boolean):void
        {
            if (!_configDone) { _pendingCalls.push({fn: this.as_showDetail, args: [value]}); return; }
            if (!_detail) return;
            if (value) _detail.show();
            else       _detail.hide();
        }

        private function _fmt(text:String, size:int, color:uint):String
        {
            return '<font face="$FieldFont" size="' + size + '" color="' + _hex(color) + '"><b>' + text + '</b></font>';
        }

        private static function _hex(color:uint):String
        {
            var h:String = color.toString(16).toUpperCase();
            while (h.length < 6) h = "0" + h;
            return "#" + h;
        }

        private static function _fmt2(value:Number):String
        {
            if (isNaN(value)) return "0.00";
            var sign:String = "";
            var v:Number = value;
            if (v < 0) { sign = "-"; v = -v; }
            var rounded:Number = Math.round(v * 100) / 100;
            var intPart:int = int(rounded);
            var frac:int = int(Math.round((rounded - intPart) * 100));
            var fracStr:String = String(frac);
            if (fracStr.length < 2) fracStr = "0" + fracStr;
            return sign + intPart.toString() + "." + fracStr;
        }
    }
}
