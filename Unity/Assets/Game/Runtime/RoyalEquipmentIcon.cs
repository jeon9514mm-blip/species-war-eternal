using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    internal sealed class RoyalEquipmentIcon : VisualElement
    {
        readonly string slot;
        readonly Color metal;
        internal RoyalEquipmentIcon(string slot,Color metal)
        {this.slot=NativeEquipmentLayout.ItemSlot(slot);this.metal=metal;pickingMode=PickingMode.Ignore;generateVisualContent+=Draw;}
        void Draw(MeshGenerationContext context)
        {
            float scale=Mathf.Min(contentRect.width,contentRect.height)/64;
            if(scale<=0)return;var p=context.painter2D;
            Vector2 V(float x,float y)=>new Vector2((contentRect.width-64*scale)/2+x*scale,(contentRect.height-64*scale)/2+y*scale);
            var dark=Color.Lerp(metal,new Color(.08f,.10f,.13f),.65f);var bright=Color.Lerp(metal,Color.white,.62f);
            void Shape(Color color,params Vector2[] points){p.fillColor=color;p.BeginPath();p.MoveTo(points[0]);foreach(var at in points)p.LineTo(at);p.ClosePath();p.Fill();}
            void Line(Color color,float width,params Vector2[] points){p.strokeColor=color;p.lineWidth=width*scale;p.BeginPath();p.MoveTo(points[0]);foreach(var at in points)p.LineTo(at);p.Stroke();}
            void Circle(float x,float y,float radius,Color color,float width=2){p.strokeColor=color;p.lineWidth=width*scale;p.BeginPath();p.Arc(V(x,y),radius*scale,0,360);p.Stroke();}
            void Gem(float x,float y){Shape(new Color(.28f,.68f,.89f),V(x,y-6),V(x+5,y),V(x,y+6),V(x-5,y));Line(bright,1,V(x,y-5),V(x-3,y));}
            if(slot=="weapon")
            {
                Shape(dark,V(14,53),V(9,49),V(39,13),V(52,5),V(48,21),V(20,54));
                Shape(bright,V(16,45),V(44,13),V(51,6),V(21,49));
                Shape(metal,V(9,38),V(15,32),V(33,48),V(29,53));Line(dark,5,V(18,47),V(10,57));Gem(20,41);
            }
            else if(slot=="helmet")
            {
                Shape(dark,V(12,49),V(14,25),V(23,12),V(40,12),V(51,26),V(51,49),V(40,55),V(23,55));
                Shape(metal,V(14,24),V(22,14),V(32,11),V(32,31),V(14,37));Shape(bright,V(32,12),V(41,16),V(50,27),V(33,30));
                Line(bright,2,V(15,40),V(48,35));Line(Color.black,3,V(20,37),V(28,37));Line(Color.black,3,V(36,36),V(44,35));Gem(32,23);
            }
            else if(slot=="armor")
            {
                Shape(dark,V(8,18),V(23,12),V(31,21),V(41,12),V(57,21),V(48,34),V(46,56),V(18,56),V(17,33));
                Shape(metal,V(20,22),V(32,26),V(45,22),V(44,48),V(32,55),V(20,48));Shape(bright,V(20,22),V(32,26),V(32,53),V(22,44));
                Line(dark,2,V(21,40),V(43,40));Line(metal,3,V(9,21),V(18,27));Gem(32,34);
            }
            else if(slot=="gloves")
            {
                Shape(dark,V(16,51),V(11,31),V(13,22),V(19,24),V(20,11),V(26,12),V(28,9),V(34,11),V(36,15),V(43,14),V(49,25),V(49,47),V(43,57),V(19,57));
                Shape(metal,V(17,30),V(25,24),V(45,24),V(44,44),V(20,47));Line(bright,2,V(20,34),V(41,32));Shape(bright,V(20,49),V(43,48),V(43,55),V(20,56));
            }
            else if(slot=="boots")
            {
                Shape(dark,V(21,8),V(44,8),V(40,37),V(54,45),V(56,54),V(8,54),V(10,44),V(20,37));
                Shape(metal,V(24,11),V(42,10),V(37,37),V(25,39));Shape(bright,V(11,46),V(28,41),V(40,42),V(51,49),V(11,49));Line(metal,3,V(9,54),V(55,54));Gem(31,21);
            }
            else if(slot=="belt")
            {
                Shape(dark,V(6,25),V(58,25),V(58,43),V(6,43));Line(metal,2,V(7,28),V(57,28));Line(metal,2,V(7,40),V(57,40));
                Shape(metal,V(22,20),V(44,20),V(44,47),V(22,47));Shape(dark,V(26,25),V(40,25),V(40,42),V(26,42));Gem(33,33);
            }
            else if(slot=="ring"||slot=="bracelet")
            {Circle(32,37,slot=="ring"?17:23,dark,7);Circle(32,35,slot=="ring"?17:23,metal,4);Circle(32,34,slot=="ring"?14:20,bright,1);Gem(32,16);}
            else if(slot=="accessory")
            {Line(dark,4,V(12,9),V(14,25),V(32,49),V(50,25),V(52,9));Line(metal,2,V(12,9),V(14,24),V(32,47),V(50,24),V(52,9));Circle(32,46,9,metal,3);Gem(32,46);}
            else
            {Shape(dark,V(32,5),V(52,24),V(42,54),V(21,57),V(10,25));Shape(metal,V(32,8),V(49,24),V(33,51),V(15,26));Shape(bright,V(32,8),V(33,49),V(21,36),V(15,25));}
        }
    }
}
