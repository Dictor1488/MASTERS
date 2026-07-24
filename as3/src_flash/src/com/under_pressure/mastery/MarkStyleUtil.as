package com.under_pressure.mastery
{
    import flash.display.Graphics;
    import flash.display.Shape;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;

    /**
     * Спільні утиліти для всіх стилів мітки.
     * Не має стану — лише статичні хелпери (форматування чисел,
     * малювання зірок, прогрес-барів, milestone-розрахунки).
     *
     * Кожен рендер стилю (Classic/Compact/Polaroid/Neer/Minimal)
     * використовує ці методи, щоб логіка була єдина.
     */
    public class MarkStyleUtil
    {
        public static const FONT_FACE:String       = "Arial";
        public static const TITLE_FONT_FACE:String  = "Arial";

        // спільні кольори
        public static const COLOR_LABEL:uint = 0xFFFFFF;
        public static const COLOR_DIM:uint   = 0x98A6B3;
        public static const COLOR_GREEN:uint = 0xB6E86A;
        public static const COLOR_RED:uint   = 0xD64A4A;
        public static const FRAME_COLOR:uint = 0xAEB8C2;

        // milestone-пороги (спільні для всіх стилів)
        public static const MILESTONE_PCTS:Array   = [65.0, 85.0, 95.0];
        public static const MILESTONE_COLORS:Array = [0x78909C, 0xC0C0C0, 0xC8B97A];

        private static const MOE_CALC_KOEFF:Number = 2.0 / 101.0;

        // ── milestone / damage розрахунки ──────────────────────────────────

        public static function nearestMilestone(projMark:Number):int
        {
            for (var i:int = 0; i < MILESTONE_PCTS.length; i++)
                if (projMark < Number(MILESTONE_PCTS[i])) return i;
            return MILESTONE_PCTS.length - 1;
        }

        public static function milestoneRequiredDamage(idx:int, p65:int, p85:int, p95:int):int
        {
            if (idx == 0) return p65;
            if (idx == 1) return p85;
            return p95;
        }

        public static function projectedAverage(currentDamage:int, baseDamage:int):int
        {
            if (baseDamage <= 0) return 0;
            return int(Math.round(
                Number(baseDamage) * (1.0 - MOE_CALC_KOEFF) + Number(currentDamage) * MOE_CALC_KOEFF
            ));
        }

        public static function estimateMarkFromDamage(damage:int, p65:int, p85:int, p95:int, p100:int):Number
        {
            var points:Array = [
                { pct: 65.0,  val: Number(p65)  },
                { pct: 85.0,  val: Number(p85)  },
                { pct: 95.0,  val: Number(p95)  },
                { pct: 100.0, val: Number(p100) }
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
                prevPct = np; prevVal = nv;
            }
            return prevPct;
        }

        // ── зірки ──────────────────────────────────────────────────────────

        public static function starPath(g:Graphics, cx:Number, cy:Number, r1:Number, r2:Number):void
        {
            var a:Number = -Math.PI / 2, step:Number = Math.PI / 5;
            g.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
            for (var i:int = 1; i <= 10; i++)
            {
                a += step;
                var r:Number = (i % 2 == 0) ? r1 : r2;
                g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
            }
        }

        // ── форматування ────────────────────────────────────────────────────

        public static function fmtBold(text:String, size:int, color:uint):String
        {
            return "<font face='" + FONT_FACE + "' size='" + size + "' color='#" + _hex(color) + "'><b>" + text + "</b></font>";
        }
        public static function fmtTitle(text:String, size:int, color:uint):String
        {
            return "<font face='" + TITLE_FONT_FACE + "' size='" + size + "' color='#" + _hex(color) + "'>" + text + "</font>";
        }
        public static function fmt(text:String, size:int, color:uint):String
        {
            return "<font face='" + FONT_FACE + "' size='" + size + "' color='#" + _hex(color) + "'>" + text + "</font>";
        }
        public static function fmt2(value:Number):String
        {
            return (isNaN(value) ? 0.0 : value).toFixed(2);
        }
        public static function fmtNum(value:int):String
        {
            var s:String = Math.abs(value).toString(), out:String = "";
            while (s.length > 3) { out = " " + s.substr(s.length - 3) + out; s = s.substr(0, s.length - 3); }
            out = s + out;
            return value < 0 ? "-" + out : out;
        }

        private static function _hex(color:uint):String
        {
            var hex:String = color.toString(16);
            while (hex.length < 6) hex = "0" + hex;
            return hex;
        }
    }
}
