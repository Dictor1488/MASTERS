package com.under_pressure.mastery
{
 import flash.display.Sprite;
 public class MasteryBattleMarkBadge extends Sprite
 {
  public static const STYLE_CLASSIC:int=0, STYLE_COMPACT:int=1, STYLE_POLAROID:int=2, STYLE_NEER:int=3, STYLE_MINIMAL:int=4, STYLE_COUNT:int=5;
  private var r:MasteryBattleRendererBase; private var s:int=0; private var ex:Boolean=false; private var dead:Boolean=false; private var off:Array=[-1,-1];
  private var m:Number=0,p65:int=0,p85:int=0,p95:int=0,p100:int=0,cur:int=-1,base:int=0,stars:int=-1,pm:Number=-1,pa:int=0;
  public function MasteryBattleMarkBadge(){super();mouseEnabled=false;mouseChildren=true;visible=false;swap();}
  public function setExpanded(v:Boolean):void{if(dead)return;ex=v;if(r)r.setExpanded(v);}
  public function setStyle(v:int):void{if(dead)return;if(v<0||v>=STYLE_COUNT)v=0;if(s==v&&r)return;s=v;swap();}
  public function setData(a:Number,b:int,c:int,d:int,e:int,f:int,g:int,h:int,i:Number=-1,j:int=0):void{m=a;p65=b;p85=c;p95=d;p100=e;cur=f;base=g;stars=h;pm=i;pa=j;apply();}
  public function setCurrentDamage(v:int):void{cur=v;pm=-1;pa=0;if(r)r.setCurrentDamage(v);}
  public function setPositionOffset(v:Array):void{if(v&&v.length>=2)off=[int(v[0]),int(v[1])];if(r)r.setPositionOffset(off);}
  public function updatePosition():void{if(r)r.updatePosition();}
  public function dispose():void{if(dead)return;dead=true;drop();}
  private function swap():void{drop();if(s==1)r=new MasteryCompactRenderer();else if(s==2)r=new MasteryPolaroidRenderer();else if(s==3)r=new MasteryNeerBadgeRenderer();else if(s==4)r=new MasteryMinimalBadgeRenderer();else r=new MasteryClassicRenderer();r.visible=true;r.setExpanded(ex);r.setPositionOffset(off);r.addEventListener(MasteryPanelEvent.BATTLE_BADGE_OFFSET_CHANGED,onOff);addChild(r);apply();r.updatePosition();}
  private function apply():void{if(r)r.setData(m,p65,p85,p95,p100,cur,base,stars,pm,pa);}
  private function drop():void{if(!r)return;r.removeEventListener(MasteryPanelEvent.BATTLE_BADGE_OFFSET_CHANGED,onOff);if(r.parent==this)removeChild(r);r.dispose();r=null;}
  private function onOff(e:MasteryPanelEvent):void{off=(e.data is Array)?e.data.concat():off;dispatchEvent(new MasteryPanelEvent(MasteryPanelEvent.BATTLE_BADGE_OFFSET_CHANGED,off));}
 }
}