package com.under_pressure.mastery
{
    import flash.events.Event;

    public class MasteryPanelEvent extends Event
    {
        public static const OFFSET_CHANGED:String    = "MasteryPanel.offsetChanged";
        public static const VIEW_MODE_CHANGED:String = "MasteryPanel.viewModeChanged";
        public static const EXPAND_TOGGLE:String     = "MasteryPanel.expandToggle";
        public static const MARK_BADGE_TOGGLE:String = "MasteryPanel.markBadgeToggle";
        public static const MARK_BADGE_OFFSET_CHANGED:String = "MasteryPanel.markBadgeOffsetChanged";
        public static const BATTLE_BADGE_OFFSET_CHANGED:String = "MasteryPanel.battleBadgeOffsetChanged";

        public var data:*;

        public function MasteryPanelEvent(type:String, data:* = null, bubbles:Boolean = false, cancelable:Boolean = false)
        {
            super(type, bubbles, cancelable);
            this.data = data;
        }

        override public function clone():Event
        {
            return new MasteryPanelEvent(type, data, bubbles, cancelable);
        }
    }
}
