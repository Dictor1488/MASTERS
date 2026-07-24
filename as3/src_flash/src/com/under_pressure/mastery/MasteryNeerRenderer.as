package com.under_pressure.mastery
{
    import flash.display.Sprite;
    import flash.display.Shape;
    import flash.display.Graphics;
    import flash.display.BitmapData;
    import flash.display.Bitmap;
    import flash.display.GradientType;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;
    import flash.geom.Point;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;

    /**
     * NEER style renderer for the battle mastery badge (style 3).
     * Draws a golden tank silhouette filled by projected mark %,
     * green (delta>=0) or red (delta<0), with skewed marks,
     * a delta pill badge and a big percentage readout.
     *
     * Colors sampled from reference PNG:
     *   green fill  = 0x018644
     *   red fill    = 0xC51917
     *   gold outline= 0xEAD7B7
     */
    public class MasteryNeerRenderer extends Sprite
    {
        // canvas 406x260, tank bbox
        private static const CW:int = 406;
        private static const CH:int = 260;
        private static const TANK_X0:Number = 170;
        private static const TANK_X1:Number = 336;
        private static const TANK_Y0:Number = 59;
        private static const TANK_Y1:Number = 133;

        private static const GREEN:uint = 0x018644;
        private static const RED:uint   = 0xC51917;
        private static const GOLD:uint  = 0xEAD7B7;

        // tuned params (from HTML editor)
        private static const FILL_ALPHA_TOP:Number = 1.00;
        private static const FILL_FADE_BOTTOM:Number = 1.00;  // 100%
        private static const CENTER_FADE:Number = 0.36;
        private static const CENTER_HIDE:Number = 0.40;
        private static const BOTTOM_HIDE:Number = 1.00;
        private static const BADGE_FADE:Number = 0.94;

        private var _fillShape:Shape;
        private var _maskBmp:Bitmap;
        private var _maskData:BitmapData;
        private var _contourShape:Shape;
        private var _marksShape:Shape;
        private var _pctField:TextField;
        private var _badgeShape:Shape;
        private var _deltaField:TextField;

        private var _silData:BitmapData;   // white silhouette (interior)
        private var _fillResult:BitmapData; // перевикористовуваний буфер заливки
        private var _contourResult:BitmapData; // буфер контуру з fade
        private static const ORIGIN:Point = new Point(0, 0);

        public function MasteryNeerRenderer()
        {
            _buildSilhouette();

            _fillShape = new Shape();
            addChild(_fillShape);

            _contourShape = new Shape();
            addChild(_contourShape);

            _marksShape = new Shape();
            addChild(_marksShape);

            _badgeShape = new Shape();
            addChild(_badgeShape);

            _pctField = _makeField(22, true);
            addChild(_pctField);

            _deltaField = _makeField(12, true);
            addChild(_deltaField);
        }

        private function _makeField(size:int, bold:Boolean):TextField
        {
            var tf:TextField = new TextField();
            tf.selectable = false;
            tf.mouseEnabled = false;
            tf.autoSize = TextFieldAutoSize.CENTER;
            var fmt:TextFormat = new TextFormat();
            fmt.font = "Arial";
            fmt.size = size;
            fmt.bold = bold;
            fmt.color = 0xFFFFFF;
            tf.defaultTextFormat = fmt;
            return tf;
        }

        /** Trace the tank contour into a Graphics object (shared by silhouette + outline). */
        private function _traceContour(g:Graphics):void
        {
            g.moveTo(200.0, 131.0);
            g.lineTo(198.9, 130.2);
            g.lineTo(198.6, 130.0);
            g.lineTo(197.9, 129.6);
            g.lineTo(197.3, 129.2);
            g.lineTo(196.8, 128.7);
            g.lineTo(196.3, 128.2);
            g.lineTo(195.7, 127.8);
            g.lineTo(195.2, 127.3);
            g.lineTo(194.7, 126.8);
            g.lineTo(194.1, 126.4);
            g.lineTo(193.6, 125.9);
            g.lineTo(193.3, 125.2);
            g.lineTo(193.1, 124.4);
            g.lineTo(192.9, 123.6);
            g.lineTo(192.7, 122.8);
            g.lineTo(192.4, 122.1);
            g.lineTo(191.9, 121.6);
            g.lineTo(191.3, 121.2);
            g.lineTo(190.8, 120.7);
            g.lineTo(190.5, 120.2);
            g.lineTo(190.5, 119.8);
            g.lineTo(190.8, 119.3);
            g.lineTo(191.2, 118.7);
            g.lineTo(191.5, 118.2);
            g.lineTo(191.5, 117.8);
            g.lineTo(191.2, 117.5);
            g.lineTo(190.8, 117.5);
            g.lineTo(190.5, 117.8);
            g.lineTo(190.4, 118.1);
            g.lineTo(190.4, 118.3);
            g.lineTo(190.4, 118.3);
            g.lineTo(190.3, 118.0);
            g.lineTo(190.0, 117.5);
            g.lineTo(189.7, 117.0);
            g.lineTo(189.6, 116.5);
            g.lineTo(189.7, 116.0);
            g.lineTo(190.0, 115.5);
            g.lineTo(190.5, 115.0);
            g.lineTo(190.9, 114.6);
            g.lineTo(191.0, 114.3);
            g.lineTo(190.8, 114.1);
            g.lineTo(190.4, 113.9);
            g.lineTo(189.8, 113.7);
            g.lineTo(189.1, 113.4);
            g.lineTo(188.6, 112.9);
            g.lineTo(188.3, 112.2);
            g.lineTo(188.2, 111.5);
            g.lineTo(188.3, 110.8);
            g.lineTo(188.6, 110.0);
            g.lineTo(189.1, 109.3);
            g.lineTo(189.7, 108.7);
            g.lineTo(190.2, 108.0);
            g.lineTo(190.7, 107.3);
            g.lineTo(191.3, 106.8);
            g.lineTo(191.9, 106.4);
            g.lineTo(192.5, 106.0);
            g.lineTo(193.2, 105.7);
            g.lineTo(194.0, 105.5);
            g.lineTo(194.8, 105.3);
            g.lineTo(195.5, 105.0);
            g.lineTo(196.2, 104.7);
            g.lineTo(196.9, 104.6);
            g.lineTo(197.5, 104.6);
            g.lineTo(198.0, 104.7);
            g.lineTo(198.5, 105.0);
            g.lineTo(199.1, 105.4);
            g.lineTo(199.7, 105.6);
            g.lineTo(200.3, 105.6);
            g.lineTo(200.9, 105.4);
            g.lineTo(201.3, 105.0);
            g.lineTo(201.4, 104.5);
            g.lineTo(201.4, 103.9);
            g.lineTo(201.3, 103.2);
            g.lineTo(201.2, 102.5);
            g.lineTo(201.4, 101.9);
            g.lineTo(201.8, 101.5);
            g.lineTo(202.3, 101.4);
            g.lineTo(202.9, 101.6);
            g.lineTo(203.4, 102.1);
            g.lineTo(203.6, 102.7);
            g.lineTo(203.6, 103.1);
            g.lineTo(203.4, 103.3);
            g.lineTo(203.0, 103.4);
            g.lineTo(202.8, 103.4);
            g.lineTo(202.0, 103.0);
            g.moveTo(203.0, 101.0);
            g.lineTo(204.1, 99.6);
            g.lineTo(204.6, 99.5);
            g.lineTo(205.5, 99.1);
            g.lineTo(206.5, 99.0);
            g.lineTo(207.5, 99.0);
            g.lineTo(208.4, 98.9);
            g.lineTo(209.2, 98.7);
            g.lineTo(210.0, 98.5);
            g.lineTo(210.8, 98.3);
            g.lineTo(211.6, 98.1);
            g.lineTo(212.5, 98.0);
            g.lineTo(213.5, 98.0);
            g.lineTo(214.5, 98.0);
            g.lineTo(215.5, 98.0);
            g.lineTo(216.5, 98.0);
            g.lineTo(217.5, 98.0);
            g.lineTo(218.5, 98.0);
            g.lineTo(219.5, 98.0);
            g.lineTo(220.5, 98.0);
            g.lineTo(221.5, 98.0);
            g.lineTo(222.5, 98.0);
            g.lineTo(223.5, 98.0);
            g.lineTo(224.5, 98.0);
            g.lineTo(225.5, 98.0);
            g.lineTo(226.5, 98.0);
            g.lineTo(227.4, 97.9);
            g.lineTo(228.0, 97.7);
            g.lineTo(228.3, 97.4);
            g.lineTo(228.4, 96.9);
            g.lineTo(228.4, 96.3);
            g.lineTo(228.4, 95.7);
            g.lineTo(228.4, 95.1);
            g.lineTo(228.4, 94.5);
            g.lineTo(228.4, 93.9);
            g.lineTo(228.2, 93.3);
            g.lineTo(227.7, 92.8);
            g.lineTo(227.1, 92.4);
            g.lineTo(226.4, 92.1);
            g.lineTo(225.5, 92.0);
            g.lineTo(224.5, 92.0);
            g.lineTo(223.5, 92.0);
            g.lineTo(222.5, 92.0);
            g.lineTo(221.5, 92.0);
            g.lineTo(220.6, 91.9);
            g.lineTo(219.8, 91.7);
            g.lineTo(219.0, 91.5);
            g.lineTo(218.2, 91.3);
            g.lineTo(217.4, 91.1);
            g.lineTo(216.5, 91.0);
            g.lineTo(215.5, 91.0);
            g.lineTo(214.5, 91.0);
            g.lineTo(213.5, 91.0);
            g.lineTo(212.5, 91.0);
            g.lineTo(211.5, 91.0);
            g.lineTo(210.5, 91.0);
            g.lineTo(209.5, 91.0);
            g.lineTo(208.5, 91.0);
            g.lineTo(207.5, 91.0);
            g.lineTo(206.5, 91.1);
            g.lineTo(205.5, 91.3);
            g.lineTo(204.5, 91.5);
            g.lineTo(203.5, 91.7);
            g.lineTo(202.5, 91.8);
            g.lineTo(201.5, 91.7);
            g.lineTo(200.5, 91.5);
            g.lineTo(199.5, 91.3);
            g.lineTo(198.5, 91.1);
            g.lineTo(197.5, 91.0);
            g.lineTo(196.5, 91.0);
            g.lineTo(195.5, 91.0);
            g.lineTo(194.5, 91.0);
            g.lineTo(193.5, 91.0);
            g.lineTo(192.5, 91.0);
            g.lineTo(191.5, 91.0);
            g.lineTo(190.5, 91.0);
            g.lineTo(189.6, 90.9);
            g.lineTo(188.8, 90.7);
            g.lineTo(188.0, 90.5);
            g.lineTo(187.2, 90.3);
            g.lineTo(186.5, 90.0);
            g.lineTo(185.8, 89.7);
            g.lineTo(185.0, 89.5);
            g.lineTo(184.2, 89.4);
            g.lineTo(183.4, 89.4);
            g.lineTo(182.6, 89.6);
            g.lineTo(181.8, 90.0);
            g.lineTo(181.1, 90.4);
            g.lineTo(180.8, 90.6);
            g.lineTo(180.0, 91.0);
            g.moveTo(180.0, 91.0);
            g.lineTo(178.8, 90.2);
            g.lineTo(178.3, 90.0);
            g.lineTo(177.4, 89.6);
            g.lineTo(176.5, 89.3);
            g.lineTo(175.5, 89.1);
            g.lineTo(174.5, 89.0);
            g.lineTo(173.6, 88.9);
            g.lineTo(172.8, 88.7);
            g.lineTo(172.1, 88.4);
            g.lineTo(171.5, 88.0);
            g.lineTo(171.0, 87.5);
            g.lineTo(170.6, 86.9);
            g.lineTo(170.3, 86.2);
            g.lineTo(170.2, 85.4);
            g.lineTo(170.4, 84.6);
            g.lineTo(170.9, 83.9);
            g.lineTo(171.5, 83.3);
            g.lineTo(172.2, 82.8);
            g.lineTo(173.0, 82.5);
            g.lineTo(173.8, 82.4);
            g.lineTo(174.6, 82.4);
            g.lineTo(175.5, 82.5);
            g.lineTo(176.4, 82.6);
            g.lineTo(177.2, 82.6);
            g.lineTo(178.0, 82.5);
            g.lineTo(178.8, 82.3);
            g.lineTo(179.6, 82.1);
            g.lineTo(180.3, 82.0);
            g.lineTo(180.8, 82.0);
            g.lineTo(181.1, 82.0);
            g.lineTo(181.0, 82.0);
            g.moveTo(179.0, 82.0);
            g.lineTo(180.0, 81.4);
            g.lineTo(180.3, 81.5);
            g.lineTo(180.8, 81.5);
            g.lineTo(181.1, 81.7);
            g.lineTo(181.2, 81.9);
            g.lineTo(181.0, 82.0);
            g.moveTo(182.0, 82.0);
            g.lineTo(182.8, 83.1);
            g.lineTo(183.1, 83.3);
            g.lineTo(183.7, 83.8);
            g.lineTo(184.3, 84.2);
            g.lineTo(184.9, 84.4);
            g.lineTo(185.4, 84.3);
            g.lineTo(185.8, 84.1);
            g.lineTo(186.3, 83.8);
            g.lineTo(186.9, 83.4);
            g.lineTo(187.6, 83.1);
            g.lineTo(188.5, 83.0);
            g.lineTo(189.5, 83.0);
            g.lineTo(190.4, 83.1);
            g.lineTo(191.2, 83.3);
            g.lineTo(192.0, 83.5);
            g.lineTo(192.8, 83.7);
            g.lineTo(193.6, 83.9);
            g.lineTo(194.5, 84.0);
            g.lineTo(195.5, 84.0);
            g.lineTo(196.5, 84.0);
            g.lineTo(197.5, 84.0);
            g.lineTo(198.5, 84.0);
            g.lineTo(199.5, 84.0);
            g.lineTo(200.5, 84.1);
            g.lineTo(201.5, 84.3);
            g.lineTo(202.5, 84.5);
            g.lineTo(203.5, 84.7);
            g.lineTo(204.4, 85.0);
            g.lineTo(205.2, 85.3);
            g.lineTo(206.0, 85.5);
            g.lineTo(206.7, 85.8);
            g.lineTo(207.3, 86.2);
            g.lineTo(208.0, 86.5);
            g.lineTo(208.8, 86.7);
            g.lineTo(209.6, 86.9);
            g.lineTo(210.5, 87.0);
            g.lineTo(211.5, 87.0);
            g.lineTo(212.5, 87.0);
            g.lineTo(213.5, 87.0);
            g.lineTo(214.5, 87.0);
            g.lineTo(215.5, 87.0);
            g.lineTo(216.5, 87.0);
            g.lineTo(217.5, 87.0);
            g.lineTo(218.5, 87.0);
            g.lineTo(219.5, 87.0);
            g.lineTo(220.5, 87.0);
            g.lineTo(221.5, 87.0);
            g.lineTo(222.5, 87.0);
            g.lineTo(223.5, 87.0);
            g.lineTo(224.5, 87.0);
            g.lineTo(225.5, 87.0);
            g.lineTo(226.5, 87.0);
            g.lineTo(227.4, 87.0);
            g.lineTo(227.9, 87.0);
            g.lineTo(229.0, 87.0);
            g.moveTo(174.0, 84.0);
            g.lineTo(172.6, 84.5);
            g.lineTo(172.6, 84.9);
            g.lineTo(172.5, 85.5);
            g.lineTo(172.8, 86.0);
            g.lineTo(173.2, 86.2);
            g.lineTo(173.6, 86.0);
            g.lineTo(173.9, 85.5);
            g.lineTo(174.0, 85.1);
            g.lineTo(174.0, 84.0);
            g.moveTo(229.0, 87.0);
            g.lineTo(230.1, 86.2);
            g.lineTo(230.4, 86.0);
            g.lineTo(231.1, 85.6);
            g.lineTo(231.9, 85.3);
            g.lineTo(232.8, 85.0);
            g.lineTo(233.7, 84.6);
            g.lineTo(234.7, 84.2);
            g.lineTo(235.6, 83.9);
            g.lineTo(236.3, 83.7);
            g.lineTo(237.0, 83.6);
            g.lineTo(237.8, 83.7);
            g.lineTo(238.6, 83.9);
            g.lineTo(239.4, 83.9);
            g.lineTo(240.2, 83.7);
            g.lineTo(241.0, 83.5);
            g.lineTo(241.7, 83.2);
            g.lineTo(242.3, 82.8);
            g.lineTo(243.0, 82.4);
            g.lineTo(243.8, 81.9);
            g.lineTo(244.5, 81.2);
            g.lineTo(245.1, 80.4);
            g.lineTo(245.7, 79.6);
            g.lineTo(246.2, 78.8);
            g.lineTo(246.6, 78.1);
            g.lineTo(247.1, 77.6);
            g.lineTo(247.8, 77.3);
            g.lineTo(248.6, 77.0);
            g.lineTo(249.5, 76.7);
            g.lineTo(250.5, 76.5);
            g.lineTo(251.5, 76.3);
            g.lineTo(252.5, 76.1);
            g.lineTo(253.5, 76.0);
            g.lineTo(254.5, 76.0);
            g.lineTo(255.5, 76.0);
            g.lineTo(256.5, 76.0);
            g.lineTo(257.5, 76.0);
            g.lineTo(258.5, 76.0);
            g.lineTo(259.5, 76.0);
            g.lineTo(260.5, 76.0);
            g.lineTo(261.5, 76.0);
            g.lineTo(262.5, 76.0);
            g.lineTo(263.5, 76.0);
            g.lineTo(264.5, 76.0);
            g.lineTo(265.5, 76.0);
            g.lineTo(266.4, 76.1);
            g.lineTo(267.0, 76.4);
            g.lineTo(267.2, 76.9);
            g.lineTo(267.2, 77.5);
            g.lineTo(267.2, 78.1);
            g.lineTo(267.3, 78.6);
            g.lineTo(267.7, 78.9);
            g.lineTo(268.4, 79.0);
            g.lineTo(268.9, 79.0);
            g.lineTo(270.0, 79.0);
            g.moveTo(270.0, 79.0);
            g.lineTo(272.5, 79.0);
            g.lineTo(273.1, 78.9);
            g.lineTo(274.4, 78.7);
            g.lineTo(275.5, 78.5);
            g.lineTo(276.4, 78.2);
            g.lineTo(277.2, 77.8);
            g.lineTo(278.0, 77.4);
            g.lineTo(278.7, 76.9);
            g.lineTo(279.3, 76.3);
            g.lineTo(280.0, 75.8);
            g.lineTo(280.8, 75.4);
            g.lineTo(281.6, 75.1);
            g.lineTo(282.5, 75.0);
            g.lineTo(283.5, 75.0);
            g.lineTo(284.5, 75.0);
            g.lineTo(285.5, 75.0);
            g.lineTo(286.5, 75.0);
            g.lineTo(287.4, 75.1);
            g.lineTo(288.2, 75.3);
            g.lineTo(289.0, 75.6);
            g.lineTo(289.7, 76.1);
            g.lineTo(290.3, 76.7);
            g.lineTo(290.9, 77.1);
            g.lineTo(291.4, 77.2);
            g.lineTo(291.8, 77.1);
            g.lineTo(292.2, 76.9);
            g.lineTo(292.5, 76.8);
            g.lineTo(292.8, 77.0);
            g.lineTo(293.3, 77.5);
            g.lineTo(293.9, 78.1);
            g.lineTo(294.6, 78.7);
            g.lineTo(295.4, 79.3);
            g.lineTo(296.2, 79.8);
            g.lineTo(297.0, 80.2);
            g.lineTo(297.8, 80.6);
            g.lineTo(298.6, 80.8);
            g.lineTo(299.5, 80.7);
            g.lineTo(300.5, 80.5);
            g.lineTo(301.5, 80.3);
            g.lineTo(302.5, 80.1);
            g.lineTo(303.5, 80.0);
            g.lineTo(304.5, 80.0);
            g.lineTo(305.5, 80.0);
            g.lineTo(306.4, 80.1);
            g.lineTo(307.1, 80.4);
            g.lineTo(307.6, 80.9);
            g.lineTo(307.9, 81.6);
            g.lineTo(307.9, 82.5);
            g.lineTo(307.6, 83.4);
            g.lineTo(307.2, 84.2);
            g.lineTo(306.8, 85.0);
            g.lineTo(306.4, 85.8);
            g.lineTo(306.1, 86.6);
            g.lineTo(306.0, 87.5);
            g.lineTo(306.1, 88.4);
            g.lineTo(306.3, 89.2);
            g.lineTo(306.6, 90.0);
            g.lineTo(306.9, 90.7);
            g.lineTo(307.1, 91.3);
            g.lineTo(307.2, 92.0);
            g.lineTo(307.1, 92.7);
            g.lineTo(306.8, 93.3);
            g.lineTo(306.5, 94.0);
            g.lineTo(306.4, 94.7);
            g.lineTo(306.4, 95.3);
            g.lineTo(306.6, 96.0);
            g.lineTo(307.1, 96.8);
            g.lineTo(307.8, 97.5);
            g.lineTo(308.6, 98.1);
            g.lineTo(309.5, 98.6);
            g.lineTo(310.5, 98.9);
            g.lineTo(311.5, 98.9);
            g.lineTo(312.5, 98.7);
            g.lineTo(313.5, 98.6);
            g.lineTo(314.5, 98.6);
            g.lineTo(315.5, 98.6);
            g.lineTo(316.5, 98.7);
            g.lineTo(317.5, 98.9);
            g.lineTo(318.5, 99.0);
            g.lineTo(319.4, 99.0);
            g.lineTo(319.9, 99.0);
            g.lineTo(321.0, 99.0);
            g.moveTo(321.0, 99.0);
            g.lineTo(322.9, 99.0);
            g.lineTo(323.4, 99.0);
            g.lineTo(324.5, 99.0);
            g.lineTo(325.4, 99.1);
            g.lineTo(326.2, 99.3);
            g.lineTo(326.9, 99.6);
            g.lineTo(327.4, 100.1);
            g.lineTo(327.7, 100.8);
            g.lineTo(328.0, 101.5);
            g.lineTo(328.4, 102.1);
            g.lineTo(328.8, 102.7);
            g.lineTo(329.3, 103.2);
            g.lineTo(330.0, 103.5);
            g.lineTo(330.8, 103.7);
            g.lineTo(331.5, 104.0);
            g.lineTo(332.2, 104.3);
            g.lineTo(332.9, 104.6);
            g.lineTo(333.5, 105.0);
            g.lineTo(334.1, 105.5);
            g.lineTo(334.7, 106.1);
            g.lineTo(335.2, 106.8);
            g.lineTo(335.6, 107.6);
            g.lineTo(335.9, 108.5);
            g.lineTo(336.0, 109.5);
            g.lineTo(335.9, 110.5);
            g.lineTo(335.7, 111.5);
            g.lineTo(335.4, 112.4);
            g.lineTo(335.0, 113.2);
            g.lineTo(334.6, 114.0);
            g.lineTo(334.3, 114.8);
            g.lineTo(334.1, 115.6);
            g.lineTo(334.0, 116.5);
            g.lineTo(333.9, 117.4);
            g.lineTo(333.7, 118.2);
            g.lineTo(333.5, 119.0);
            g.lineTo(333.3, 119.8);
            g.lineTo(333.1, 120.6);
            g.lineTo(333.0, 121.4);
            g.lineTo(333.0, 121.9);
            g.lineTo(333.0, 123.0);
            g.moveTo(333.0, 123.0);
            g.lineTo(331.9, 123.9);
            g.lineTo(331.6, 123.9);
            g.lineTo(331.0, 124.2);
            g.lineTo(330.6, 124.6);
            g.lineTo(330.4, 124.9);
            g.lineTo(330.4, 125.3);
            g.lineTo(330.5, 125.8);
            g.lineTo(330.8, 126.1);
            g.lineTo(331.2, 126.1);
            g.lineTo(331.5, 126.0);
            g.lineTo(331.6, 126.0);
            g.lineTo(331.6, 126.2);
            g.lineTo(331.4, 126.6);
            g.lineTo(331.0, 127.2);
            g.lineTo(330.6, 128.0);
            g.lineTo(330.2, 128.7);
            g.lineTo(329.8, 129.3);
            g.lineTo(329.5, 130.0);
            g.lineTo(329.2, 130.7);
            g.lineTo(328.8, 131.2);
            g.lineTo(328.6, 131.5);
            g.lineTo(328.0, 132.0);
            g.moveTo(253.0, 132.0);
            g.lineTo(255.5, 131.6);
            g.lineTo(256.1, 131.4);
            g.lineTo(257.4, 130.9);
            g.lineTo(258.5, 130.3);
            g.lineTo(259.4, 129.7);
            g.lineTo(260.2, 129.1);
            g.lineTo(260.9, 128.5);
            g.lineTo(261.5, 128.0);
            g.lineTo(262.2, 127.6);
            g.lineTo(263.1, 127.3);
            g.lineTo(264.1, 127.1);
            g.lineTo(265.2, 127.1);
            g.lineTo(266.4, 127.4);
            g.lineTo(267.5, 127.9);
            g.lineTo(268.4, 128.6);
            g.lineTo(269.2, 129.4);
            g.lineTo(269.9, 130.2);
            g.lineTo(270.5, 130.9);
            g.lineTo(271.1, 131.4);
            g.lineTo(271.9, 131.8);
            g.lineTo(272.9, 132.2);
            g.lineTo(274.2, 132.5);
            g.lineTo(276.0, 132.7);
            g.lineTo(278.1, 132.9);
            g.lineTo(280.3, 133.0);
            g.lineTo(282.6, 133.0);
            g.lineTo(284.9, 132.9);
            g.lineTo(287.0, 132.8);
            g.lineTo(289.0, 132.8);
            g.lineTo(290.9, 132.8);
            g.lineTo(292.5, 132.8);
            g.lineTo(293.4, 132.9);
            g.lineTo(295.0, 133.0);
            g.moveTo(295.0, 133.0);
            g.lineTo(302.6, 133.0);
            g.lineTo(305.4, 133.0);
            g.lineTo(310.5, 133.0);
            g.lineTo(315.2, 133.0);
            g.lineTo(319.2, 133.0);
            g.lineTo(322.2, 132.9);
            g.lineTo(324.2, 132.7);
            g.lineTo(325.6, 132.5);
            g.lineTo(326.6, 132.3);
            g.lineTo(327.0, 132.1);
            g.lineTo(328.0, 132.0);
            g.moveTo(253.0, 132.0);
            g.lineTo(248.6, 132.0);
            g.lineTo(246.7, 132.0);
            g.lineTo(243.2, 132.0);
            g.lineTo(239.6, 132.0);
            g.lineTo(236.0, 132.0);
            g.lineTo(232.6, 132.0);
            g.lineTo(229.4, 132.0);
            g.lineTo(226.3, 132.0);
            g.lineTo(223.3, 132.0);
            g.lineTo(220.3, 132.0);
            g.lineTo(217.4, 132.0);
            g.lineTo(214.7, 132.0);
            g.lineTo(212.1, 132.0);
            g.lineTo(209.7, 132.0);
            g.lineTo(207.7, 132.0);
            g.lineTo(206.0, 132.0);
            g.lineTo(204.6, 132.0);
            g.lineTo(203.5, 131.9);
            g.lineTo(202.5, 131.7);
            g.lineTo(201.6, 131.5);
            g.lineTo(201.1, 131.4);
            g.lineTo(200.0, 131.0);
        }

        /** Build a white silhouette BitmapData by flood-filling the traced contour. */
        private function _buildSilhouette():void
        {
            // Малюємо контур товстою лінією у BitmapData
            var tmp:BitmapData = new BitmapData(CW, CH, true, 0x00000000);
            var s:Shape = new Shape();
            var g:Graphics = s.graphics;
            g.lineStyle(3, 0xFFFFFF, 1.0, false, "normal", "round", "round");
            _traceContour(g);
            tmp.draw(s);

            // Заливка "зовні" від кута → зовнішня зона стає непрозорим чорним 0xFF000000
            tmp.floodFill(0, 0, 0xFF000000);

            // Силует = все, що НЕ дорівнює зовнішньому чорному.
            // threshold: там де pixel == 0xFF000000 → пишемо 0x00000000 (прозоро),
            // решта (copySource=true) копіюється як є (біла лінія / прозоре нутро).
            // Тому спершу заллємо нутро: інвертуємо — все не-зовнішнє робимо білим.
            _silData = new BitmapData(CW, CH, true, 0x00000000);
            _silData.fillRect(_silData.rect, 0xFFFFFFFF);          // все біле
            // де tmp РІВНЕ зовнішньому чорному → у силуеті прозоро
            _silData.threshold(tmp, tmp.rect, new Point(0, 0),
                               "==", 0xFF000000, 0x00000000, 0xFFFFFFFF, false);
            tmp.dispose();
        }

        /**
         * Render the neer badge.
         * @param mark projected mark percentage 0..100
         * @param delta change vs current (sign picks green/red)
         * @param filledMarks number of earned marks 0..3
         */
        /** Звільняє BitmapData буфери (викликати при знищенні бейджа). */
        public function dispose():void
        {
            if (_silData != null)       { _silData.dispose();       _silData = null; }
            if (_fillResult != null)    { _fillResult.dispose();    _fillResult = null; }
            if (_contourResult != null) { _contourResult.dispose(); _contourResult = null; }
        }

        public function render(mark:Number, delta:Number, filledMarks:int):void
        {
            var pct:Number = Math.max(0, Math.min(1, mark / 100.0));
            var isUp:Boolean = delta >= 0;
            var fillColor:uint = isUp ? GREEN : RED;

            _drawFill(pct, fillColor);
            _drawContourFaded();
            _drawMarks(filledMarks);
            _drawBadge(delta, isUp);

            _pctField.text = _fmt2(mark) + "%";
            _pctField.x = 270 - _pctField.width / 2;
            _pctField.y = 108 - _pctField.height / 2;
        }

        /** Fill the tank interior up to pct, with vertical alpha fade. */
        private function _drawFill(pct:Number, color:uint):void
        {
            var fillBmp:BitmapData = new BitmapData(CW, CH, true, 0x00000000);

            // vertical gradient fill of the color, clipped horizontally to pct
            var fillX:Number = TANK_X0 + (TANK_X1 - TANK_X0) * pct;
            var grad:Shape = new Shape();
            var m:Matrix = new Matrix();
            m.createGradientBox(CW, TANK_Y1 - TANK_Y0, Math.PI / 2, 0, TANK_Y0);
            var topA:Number = FILL_ALPHA_TOP;
            var botA:Number = topA * (1 - FILL_FADE_BOTTOM);
            grad.graphics.beginGradientFill(GradientType.LINEAR,
                [color, color], [topA, botA], [0, 255], m);
            grad.graphics.drawRect(0, 0, fillX, CH);
            grad.graphics.endFill();

            // composite: gradient masked by silhouette (source-in emulation)
            fillBmp.draw(grad);
            if (_fillResult != null) _fillResult.dispose();
            _fillResult = new BitmapData(CW, CH, true, 0x00000000);
            _fillResult.copyPixels(fillBmp, fillBmp.rect, new Point(0, 0), _silData, new Point(0, 0), true);

            _fillShape.graphics.clear();
            _fillShape.graphics.beginBitmapFill(_fillResult, null, false, true);
            _fillShape.graphics.drawRect(0, 0, CW, CH);
            _fillShape.graphics.endFill();

            fillBmp.dispose();
        }

        /** Draw the gold contour (solid, без ризикованої mask). */
        private function _drawContourFaded():void
        {
            var g:Graphics = _contourShape.graphics;
            g.clear();
            _contourShape.mask = null;
            _contourShape.cacheAsBitmap = false;

            // [1] малюємо золотий контур у BitmapData
            var line:Shape = new Shape();
            line.graphics.lineStyle(1.05, GOLD, 1.0, false, "normal", "round", "round");
            _traceContour(line.graphics);
            var lineBmp:BitmapData = new BitmapData(CW, CH, true, 0x00000000);
            lineBmp.draw(line);

            // [2] вертикальний градієнт прозорості:
            //    верх повний (1), від centerFade починає гаснути,
            //    центр = 1-CENTER_HIDE, низ = 1-BOTTOM_HIDE
            var gradShape:Shape = new Shape();
            var m:Matrix = new Matrix();
            m.createGradientBox(CW, TANK_Y1 - TANK_Y0, Math.PI / 2, 0, TANK_Y0);
            var midA:Number = 1 - CENTER_HIDE;
            var botA:Number = 1 - BOTTOM_HIDE;
            var fadeStart:Number = CENTER_FADE;
            gradShape.graphics.beginGradientFill(GradientType.LINEAR,
                [0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
                [1.0, 1.0, midA, botA],
                [0, int(255 * fadeStart), int(255 * Math.min(0.99, fadeStart + 0.25)), 255], m);
            gradShape.graphics.drawRect(0, 0, CW, CH);
            gradShape.graphics.endFill();
            var gradBmp:BitmapData = new BitmapData(CW, CH, true, 0x00000000);
            gradBmp.draw(gradShape);

            // [3] множимо альфу контуру на градієнт через alphaBitmapData
            //    copyPixels з alphaBitmapData
            if (_contourResult != null) _contourResult.dispose();
            _contourResult = new BitmapData(CW, CH, true, 0x00000000);
            _contourResult.copyPixels(lineBmp, lineBmp.rect, ORIGIN, gradBmp, ORIGIN, true);

            g.beginBitmapFill(_contourResult, null, false, true);
            g.drawRect(0, 0, CW, CH);
            g.endFill();

            lineBmp.dispose();
            gradBmp.dispose();
        }

        private function _applyContourFade():void
        {
            // fade застосовано напряму в _drawContourFaded через BitmapData градієнт
        }

        private function _drawMarks(filled:int):void
        {
            var g:Graphics = _marksShape.graphics;
            g.clear();
            var cx:Number = 269, cy:Number = 60;
            var scale:Number = 1.18;
            var gap:Number = 8, w:Number = 5, h:Number = 12;
            var skew:Number = Math.tan(22 * Math.PI / 180);

            for (var i:int = 0; i < 3; i++)
            {
                var mx:Number = (i - 1) * gap;
                var a:Number = i < filled ? 1.0 : 0.3;
                var col:uint = GOLD;
                // build skewed parallelogram in local (unscaled) coords
                var x0:Number = cx + (mx - w/2 + skew*h/2) * scale;
                var x1:Number = cx + (mx + w/2 + skew*h/2) * scale;
                var x2:Number = cx + (mx + w/2 - skew*h/2) * scale;
                var x3:Number = cx + (mx - w/2 - skew*h/2) * scale;
                var yT:Number = cy - (h/2) * scale;
                var yB:Number = cy + (h/2) * scale;
                if (i < filled)
                {
                    g.beginFill(col, a);
                    g.moveTo(x0, yT); g.lineTo(x1, yT); g.lineTo(x2, yB); g.lineTo(x3, yB);
                    g.lineTo(x0, yT); g.endFill();
                }
                g.lineStyle(1, col, a);
                g.moveTo(x0, yT); g.lineTo(x1, yT); g.lineTo(x2, yB); g.lineTo(x3, yB); g.lineTo(x0, yT);
                g.lineStyle();
            }
        }

        private function _drawBadge(delta:Number, isUp:Boolean):void
        {
            var g:Graphics = _badgeShape.graphics;
            g.clear();
            var pillX:Number = 262, by:Number = 129;
            var pw:Number = 80, ph:Number = 25, pr:Number = 12, cr:Number = 9;
            var bx:Number = pillX - pw / 2;

            var topCol:uint = isUp ? GREEN : RED;
            var fadeF:Number = 1 - BADGE_FADE;
            var r:int = ((topCol >> 16) & 0xFF) * fadeF;
            var gg:int = ((topCol >> 8) & 0xFF) * fadeF;
            var b:int = (topCol & 0xFF) * fadeF;
            var botCol:uint = (r << 16) | (gg << 8) | b;

            // pill gradient
            var m:Matrix = new Matrix();
            m.createGradientBox(pw, ph, Math.PI / 2, bx, by);
            g.beginGradientFill(GradientType.LINEAR, [topCol, botCol], [1, 1], [0, 255], m);
            _roundRect(g, bx, by, pw, ph, pr);
            g.endFill();

            // cream circle inside (left)
            var ccx:Number = bx + ph / 2 + 2, ccy:Number = by + ph / 2;
            var cm:Matrix = new Matrix();
            cm.createGradientBox(cr * 2, cr * 2, 0, ccx - cr, ccy - cr);
            g.beginGradientFill(GradientType.RADIAL, [0xFFF5E3, 0xD4BF9A], [1, 1], [0, 255], cm);
            g.drawCircle(ccx, ccy, cr);
            g.endFill();

            // arrow icon
            g.lineStyle(2, botCol, 1.0, false, "normal", "round", "round");
            var ir:Number = cr * 0.4;
            if (isUp)
            {
                g.moveTo(ccx - ir, ccy + ir * 0.5);
                g.lineTo(ccx, ccy - ir * 0.7);
                g.lineTo(ccx + ir, ccy + ir * 0.5);
            }
            else
            {
                g.moveTo(ccx - ir, ccy - ir * 0.5);
                g.lineTo(ccx, ccy + ir * 0.7);
                g.lineTo(ccx + ir, ccy - ir * 0.5);
            }
            g.lineStyle();

            // delta text
            _deltaField.text = (delta > 0 ? "+" : "") + _fmt2(delta) + "%";
            _deltaField.x = ccx + cr + (pw - (ccx - bx) - cr) / 2 - 4 - _deltaField.width / 2;
            _deltaField.y = by + ph / 2 - _deltaField.height / 2;
        }

        private function _roundRect(g:Graphics, x:Number, y:Number, w:Number, h:Number, r:Number):void
        {
            g.moveTo(x + r, y);
            g.lineTo(x + w - r, y);
            g.curveTo(x + w, y, x + w, y + r);
            g.lineTo(x + w, y + h - r);
            g.curveTo(x + w, y + h, x + w - r, y + h);
            g.lineTo(x + r, y + h);
            g.curveTo(x, y + h, x, y + h - r);
            g.lineTo(x, y + r);
            g.curveTo(x, y, x + r, y);
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
