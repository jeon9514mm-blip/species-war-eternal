using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    // Live vector shading and engraved framing; no composited concept pixels.
    internal sealed class RoyalHudSurface : VisualElement
    {
        readonly bool round,ornate,steel;
        readonly Color accent;
        internal RoyalHudSurface(bool round=false,bool ornate=false,Color? accent=null,bool steel=false)
        {
            this.round=round;this.ornate=ornate;this.steel=steel;this.accent=accent??new Color(.76f,.62f,.39f);
            pickingMode=PickingMode.Ignore;style.position=Position.Absolute;
            style.left=style.right=style.top=style.bottom=0;generateVisualContent+=Draw;
        }
        void Draw(MeshGenerationContext context)
        {
            float w=contentRect.width,h=contentRect.height;if(w<1||h<1)return;
            var p=context.painter2D;
            void Polygon(Color color,params Vector2[] points)
            {p.fillColor=color;p.BeginPath();p.MoveTo(points[0]);for(int i=1;i<points.Length;i++)p.LineTo(points[i]);p.ClosePath();p.Fill();}
            void Line(Color color,float width,params Vector2[] points)
            {p.strokeColor=color;p.lineWidth=width;p.BeginPath();p.MoveTo(points[0]);for(int i=1;i<points.Length;i++)p.LineTo(points[i]);p.Stroke();}
            void Circle(float radius,Color color,bool fill=false,float width=1)
            {
                var points=new Vector2[65];for(int i=0;i<points.Length;i++)
                {float a=i*Mathf.PI/32;points[i]=new Vector2(w/2+Mathf.Cos(a)*radius,h/2+Mathf.Sin(a)*radius);}
                if(fill)Polygon(color,points);else Line(color,width,points);
            }
            if(round)
            {
                float r=Mathf.Min(w,h)/2;Circle(r-1,new Color(.04f,.06f,.075f,.95f),true);
                for(int i=0;i<12;i++)Circle((r-4)*(1-i*.052f),steel?
                    Color.Lerp(new Color(.23f,.24f,.24f),new Color(.46f,.46f,.43f),i/12f):
                    Color.Lerp(new Color(.03f,.05f,.065f),new Color(.14f,.19f,.22f),i/12f),true);
                Circle(r-2,new Color(.13f,.12f,.09f),false,4);Circle(r-3,accent,false,1.6f);
                Circle(r-7,new Color(.92f,.82f,.61f,.74f));Circle(r-10,new Color(.34f,.45f,.51f,.55f));
                if(ornate)for(int i=0;i<4;i++)
                {
                    float a=i*Mathf.PI/2;var at=new Vector2(w/2+Mathf.Cos(a)*(r-2),h/2+Mathf.Sin(a)*(r-2));
                    Polygon(accent,at+new Vector2(0,-3),at+new Vector2(2,0),at+new Vector2(0,3),at+new Vector2(-2,0));
                }
                return;
            }
            // One continuous fill avoids translucent anti-aliasing seams.
            Polygon(new Color(.025f,.034f,.044f,.97f),new Vector2(0,0),new Vector2(w,0),new Vector2(w,h),new Vector2(0,h));
            Polygon(new Color(.18f,.21f,.24f,.13f),new Vector2(0,0),new Vector2(w,0),new Vector2(w,h*.27f),new Vector2(0,h*.27f));
            Line(new Color(accent.r,accent.g,accent.b,.65f),1,new Vector2(4,1),new Vector2(w-4,1));
            Line(new Color(.84f,.75f,.57f,.23f),1,new Vector2(10,3),new Vector2(w-10,3));
            if(ornate)
            {
                Line(accent,1,new Vector2(10,0),new Vector2(3,7),new Vector2(3,h-7),new Vector2(10,h));
                Line(accent,1,new Vector2(w-10,0),new Vector2(w-3,7),new Vector2(w-3,h-7),new Vector2(w-10,h));
                Polygon(accent,new Vector2(w/2-3,0),new Vector2(w/2,4),new Vector2(w/2+3,0));
            }
        }
    }
}
