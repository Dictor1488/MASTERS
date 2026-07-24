package com.under_pressure.mastery
{
    /**
     * Polaroid renderer.
     *
     * The reference overlay shows the current 198 px frame is about 3.5%
     * wider than the target. Only horizontal size is corrected here:
     * 198 px -> 191 px. Vertical scale remains untouched so text, stars
     * and frame are not flattened.
     */
    public class MasteryPolaroidRenderer extends MasteryBattleRendererBase
    {
        private static const TARGET_WIDTH:Number = 191.0;
        private static const SOURCE_WIDTH:Number = 198.0;

        public function MasteryPolaroidRenderer()
        {
            super();
            setStyle(MasteryBattleRendererBase.STYLE_POLAROID);

            scaleX = TARGET_WIDTH / SOURCE_WIDTH;
            scaleY = 1.0;
        }
    }
}
