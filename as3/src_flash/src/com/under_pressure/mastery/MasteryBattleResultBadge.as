package com.under_pressure.mastery
{
    import flash.display.Sprite;

    /** Compatibility no-op. The obsolete results badge is intentionally disabled. */
    public class MasteryBattleResultBadge extends Sprite
    {
        public function MasteryBattleResultBadge()
        {
            super();
            visible = false;
            mouseEnabled = false;
            mouseChildren = false;
        }

        public function setTitle(value:String):void {}
        public function setData(currentMark:Number, delta:Number):void { visible = false; }
        public function dispose():void {}
    }
}
