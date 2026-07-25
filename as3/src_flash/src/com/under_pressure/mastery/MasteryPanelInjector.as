package com.under_pressure.mastery
{
    import flash.events.Event;
    import net.wg.infrastructure.base.AbstractView;

    public class MasteryPanelInjector extends AbstractView
    {
        private var _panel:MasteryPanelComponent = null;

        public var py_onDragEnd:Function = null;
        public var py_onPanelReady:Function = null;
        public var py_onViewModeChanged:Function = null;
        public var py_onExpandToggle:Function = null;

        private var _configDone:Boolean = false;
        private var _pendingCalls:Array = [];
        private var _notifyFrameCount:int = 0;

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

            if (App.instance && App.instance.stage)
                App.instance.stage.addEventListener(Event.RESIZE, _onResize);

            _notifyFrameCount = 0;
            addEventListener(Event.ENTER_FRAME, _onNotifyFrame);
        }

        override protected function nextFrameAfterPopulateHandler():void
        {
            super.nextFrameAfterPopulateHandler();
            _bringToFront();
        }

        override protected function onDispose():void
        {
            removeEventListener(Event.ENTER_FRAME, _onNotifyFrame);
            if (App.instance && App.instance.stage)
                App.instance.stage.removeEventListener(Event.RESIZE, _onResize);

            _destroyPanel();
            _pendingCalls = [];
            py_onDragEnd = null;
            py_onPanelReady = null;
            py_onViewModeChanged = null;
            py_onExpandToggle = null;
            _configDone = false;
            super.onDispose();
        }

        private function _createPanel():void
        {
            if (_panel) return;
            _panel = new MasteryPanelComponent();
            _panel.addEventListener(MasteryPanelEvent.OFFSET_CHANGED, _onOffsetChanged);
            _panel.addEventListener(MasteryPanelEvent.VIEW_MODE_CHANGED, _onViewModeChanged);
            _panel.addEventListener(MasteryPanelEvent.EXPAND_TOGGLE, _onExpandToggle);
            _panel.setMarkBadgeEnabled(false);
            _panel.setVisibleState(false);
            addChild(_panel);
        }

        private function _destroyPanel():void
        {
            if (!_panel) return;
            _panel.removeEventListener(MasteryPanelEvent.OFFSET_CHANGED, _onOffsetChanged);
            _panel.removeEventListener(MasteryPanelEvent.VIEW_MODE_CHANGED, _onViewModeChanged);
            _panel.removeEventListener(MasteryPanelEvent.EXPAND_TOGGLE, _onExpandToggle);
            _panel.dispose();
            if (_panel.parent) _panel.parent.removeChild(_panel);
            _panel = null;
        }

        private function _onNotifyFrame(event:Event):void
        {
            _notifyFrameCount++;
            if (_notifyFrameCount < 5) return;
            removeEventListener(Event.ENTER_FRAME, _onNotifyFrame);
            if (py_onPanelReady != null) py_onPanelReady();
        }

        private function _onResize(event:Event):void
        {
            if (_panel) _panel.updatePosition();
        }

        private function _bringToFront():void
        {
            if (parent && parent.getChildIndex(this) != parent.numChildren - 1)
                parent.setChildIndex(this, parent.numChildren - 1);
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

        private function _queue(fn:Function, args:Array):void
        {
            _pendingCalls.push({fn: fn, args: args});
        }

        private function _replayPendingCalls():void
        {
            var calls:Array = _pendingCalls;
            _pendingCalls = [];
            for each (var call:Object in calls)
                call.fn.apply(this, call.args);
        }

        public function as_setMasteryData(third:int, second:int, first:int, ace:int):void
        {
            if (!_configDone) { _queue(as_setMasteryData, [third, second, first, ace]); return; }
            if (_panel) _panel.setMasteryData(third, second, first, ace);
        }

        public function as_setMoeData(p65:int, p85:int, p95:int, p100:int):void
        {
            if (!_configDone) { _queue(as_setMoeData, [p65, p85, p95, p100]); return; }
            if (_panel) _panel.setMoeData(p65, p85, p95, p100);
        }

        public function as_setBattleHistory(values:Array, currentMark:Number):void
        {
            if (!_configDone) { _queue(as_setBattleHistory, [values, currentMark]); return; }
            if (_panel) _panel.setBattleHistory(values, currentMark);
        }

        public function as_setLastBattleDamage(value:int):void
        {
            if (!_configDone) { _queue(as_setLastBattleDamage, [value]); return; }
            if (_panel) _panel.setLastBattleDamage(value);
        }

        public function as_setViewMode(mode:int):void
        {
            if (!_configDone) { _queue(as_setViewMode, [mode]); return; }
            if (_panel) _panel.setViewMode(mode);
        }

        public function as_setPanelBodyVisible(value:Boolean):void
        {
            if (!_configDone) { _queue(as_setPanelBodyVisible, [value]); return; }
            if (_panel) _panel.setPanelBodyVisible(value);
        }

        public function as_setMarkBadgeEnabled(value:Boolean):void
        {
            if (!_configDone) { _queue(as_setMarkBadgeEnabled, [false]); return; }
            if (_panel) _panel.setMarkBadgeEnabled(false);
        }

        public function as_setLoading():void
        {
            if (!_configDone) { _queue(as_setLoading, []); return; }
            if (_panel) _panel.setLoading();
        }

        public function as_clearData():void
        {
            if (!_configDone) { _queue(as_clearData, []); return; }
            if (_panel) _panel.clearData();
        }

        public function as_setVisible(value:Boolean):void
        {
            if (!_configDone) { _queue(as_setVisible, [value]); return; }
            if (_panel) _panel.setVisibleState(value);
        }

        public function as_setPosition(offset:Array):void
        {
            if (!_configDone) { _queue(as_setPosition, [offset]); return; }
            if (_panel) _panel.setPositionOffset(offset);
        }

        public function as_setLocalization(data:Object):void
        {
            if (!_configDone) { _queue(as_setLocalization, [data]); return; }
            if (_panel) _panel.setLocalization(data);
        }
    }
}
