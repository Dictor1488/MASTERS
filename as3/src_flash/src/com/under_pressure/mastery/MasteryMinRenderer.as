package com.under_pressure.mastery
{
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;

    /**
     * MIN style renderer — максимально простий текстовий стиль.
     *
     * Згорнутий:
     *   • великий %  (зелений delta>=0 / червоний delta<0), по центру
     *   • поточний урон (верх, справа)
     *   • урон до виходу в 0 по дельті (низ, справа)
     *
     * Розгорнутий (Alt):
     *   • рядок1: прогноз при delta=0  (% + урон)
     *   • рядок2: прогноз +1%          (% + урон)
     *
     * Кольори: % зелений/червоний, решта біла.
     */
    public class MasteryMinRenderer extends Sprite
    {
        private static const GREEN:uint = 0x5CC85C;
        private static const RED:uint   = 0xE02525;
        private static const WHITE:uint = 0xF2F2F2;

        // layout (панель ~198 ширини, компактна)
        private static const PCT_X:Number  = 66.0;
        private static const PCT_Y:Number  = 52.3;
        private static const PCT_SIZE:int  = 34;

        private static const DMG_COL_X:Number  = 155.0;
        private static const CUR_DMG_Y:Number  = 42.0;
        private static const ZERO_DMG_Y:Number = 60.0;
        private static const DMG_SIZE:int      = 14;

        // expanded rows — рівно під великим % (та ж X-колонка), одне під одним
        private static const EXP_PCT_X:Number  = 30.0;
        private static const EXP_DMG_X:Number  = 95.0;
        private static const EXP_ROW1_Y:Number = 78.0;
        private static const EXP_ROW2_Y:Number = 96.0;
        private static const EXP_SIZE:int      = 13;

        private var _pct:TextField;
        private var _curDmg:TextField;
        private var _zeroDmg:TextField;
        private var _row1Pct:TextField;
        private var _row1Dmg:TextField;
        private var _row2Pct:TextField;
        private var _row2Dmg:TextField;

        public function MasteryMinRenderer()
        {
            _pct     = _mk(PCT_SIZE, true);
            _curDmg  = _mk(DMG_SIZE, true);
            _zeroDmg = _mk(DMG_SIZE, true);
            _row1Pct = _mk(EXP_SIZE, true);
            _row1Dmg = _mk(EXP_SIZE, true);
            _row2Pct = _mk(EXP_SIZE, true);
            _row2Dmg = _mk(EXP_SIZE, true);

            addChild(_pct);
            addChild(_curDmg);
            addChild(_zeroDmg);
            addChild(_row1Pct);
            addChild(_row1Dmg);
            addChild(_row2Pct);
            addChild(_row2Dmg);
        }

        private function _mk(size:int, bold:Boolean):TextField
        {
            var tf:TextField = new TextField();
            tf.selectable = false;
            tf.mouseEnabled = false;
            tf.autoSize = TextFieldAutoSize.LEFT;
            var fmt:TextFormat = new TextFormat();
            fmt.font = "Arial";
            fmt.size = size;
            fmt.bold = bold;
            fmt.color = WHITE;
            tf.defaultTextFormat = fmt;
            return tf;
        }

        private function _set(tf:TextField, s:String, color:uint, size:int):void
        {
            var fmt:TextFormat = new TextFormat();
            fmt.font = "Arial";
            fmt.size = size;
            fmt.bold = true;
            fmt.color = color;
            tf.defaultTextFormat = fmt;
            tf.text = s;
            tf.setTextFormat(fmt);
        }

        /**
         * @param mark        прогнозована мітка %
         * @param delta       зміна (знак = колір)
         * @param currentDmg  поточний урон
         * @param zeroDmg     урон щоб вийти в 0 по дельті
         * @param expanded    Alt-режим
         * @param proj0Pct    % при delta=0
         * @param proj0Dmg    урон при delta=0
         * @param nextPct     прогноз +1%
         * @param nextDmg     урон до +1%
         */
        public function render(mark:Number, delta:Number, currentDmg:int, zeroDmg:int,
                               expanded:Boolean,
                               proj0Pct:Number, proj0Dmg:int,
                               nextPct:Number, nextDmg:int):void
        {
            var isUp:Boolean = delta >= 0;
            var pctColor:uint = isUp ? GREEN : RED;

            // великий % — центр по PCT_X
            _set(_pct, _fmt2(mark) + "%", pctColor, PCT_SIZE);
            _pct.x = PCT_X - _pct.width / 2;
            _pct.y = PCT_Y - _pct.height / 2;

            // поточний урон (верх, центр по DMG_COL_X)
            _set(_curDmg, currentDmg.toString(), WHITE, DMG_SIZE);
            _curDmg.x = DMG_COL_X - _curDmg.width / 2;
            _curDmg.y = CUR_DMG_Y - _curDmg.height / 2;

            // урон до 0 по дельті (низ)
            _set(_zeroDmg, zeroDmg.toString(), WHITE, DMG_SIZE);
            _zeroDmg.x = DMG_COL_X - _zeroDmg.width / 2;
            _zeroDmg.y = ZERO_DMG_Y - _zeroDmg.height / 2;

            // розгорнуті рядки
            _row1Pct.visible = expanded;
            _row1Dmg.visible = expanded;
            _row2Pct.visible = expanded;
            _row2Dmg.visible = expanded;

            if (expanded)
            {
                // %-колонка центрується під великим % (PCT_X), урон — під dmg-колонкою
                _set(_row1Pct, _fmt2(proj0Pct) + "%", WHITE, EXP_SIZE);
                _row1Pct.x = PCT_X - _row1Pct.width / 2;
                _row1Pct.y = EXP_ROW1_Y - _row1Pct.height / 2;

                _set(_row1Dmg, proj0Dmg.toString(), WHITE, EXP_SIZE);
                _row1Dmg.x = DMG_COL_X - _row1Dmg.width / 2;
                _row1Dmg.y = EXP_ROW1_Y - _row1Dmg.height / 2;

                _set(_row2Pct, _fmt2(nextPct) + "%", WHITE, EXP_SIZE);
                _row2Pct.x = PCT_X - _row2Pct.width / 2;
                _row2Pct.y = EXP_ROW2_Y - _row2Pct.height / 2;

                _set(_row2Dmg, nextDmg.toString(), WHITE, EXP_SIZE);
                _row2Dmg.x = DMG_COL_X - _row2Dmg.width / 2;
                _row2Dmg.y = EXP_ROW2_Y - _row2Dmg.height / 2;
            }
        }

        private function _fmt2(v:Number):String
        {
            var s:String = (Math.round(v * 100) / 100).toString();
            var dot:int = s.indexOf(".");
            if (dot < 0) return s + ".00";
            var dec:String = s.substr(dot + 1);
            while (dec.length < 2) dec += "0";
            return s.substr(0, dot) + "." + dec.substr(0, 2);
        }
    }
}
