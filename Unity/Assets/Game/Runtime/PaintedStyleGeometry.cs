using UnityEngine;

namespace Eternal.UnityMigration
{
    // Complete UV coverage supports a redesigned silhouette instead of clipping
    // it to the old character's outline. This is a modest procedural relief,
    // not a newly rigged Blender character or cloth simulation.
    public static class PaintedStyleGeometry
    {
        public static Mesh Build(string id,bool hero,bool lod=false)
        {
            int columns=hero?48:40,rows=hero?64:50;if(lod){columns/=2;rows/=2;}
            var vertices=new Vector3[(columns+1)*(rows+1)];var uv=new Vector2[vertices.Length];var indices=new int[columns*rows*6];
            for(int y=0;y<=rows;y++)for(int x=0;x<=columns;x++)
            {
                int i=y*(columns+1)+x;float u=x/(float)columns,v=y/(float)rows;
                vertices[i]=new Vector3(u,1-v,-.025f*Mathf.Sin(u*Mathf.PI)*Mathf.Sin(v*Mathf.PI));uv[i]=new Vector2(u,v);
            }
            int n=0;for(int y=0;y<rows;y++)for(int x=0;x<columns;x++){int a=y*(columns+1)+x,b=a+1,c=a+columns+1,d=c+1;indices[n++]=a;indices[n++]=c;indices[n++]=b;indices[n++]=b;indices[n++]=c;indices[n++]=d;}
            var mesh=new Mesh{name=id+" full-coverage painted relief"};mesh.vertices=vertices;mesh.uv=uv;mesh.triangles=indices;mesh.RecalculateNormals();mesh.bounds=new Bounds(new Vector3(0,1,0),new Vector3(12,12,2));return mesh;
        }
    }
}
