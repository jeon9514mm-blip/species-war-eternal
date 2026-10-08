using System;
using System.Collections.Generic;
using System.Text;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;

namespace Eternal.UnityMigration
{
    // Narrow GLB 2 reader for this repository's uncompressed static reliefs.
    // No extension, skinning, animation or arbitrary glTF scene support implied.
    public static class OriginalReliefMesh
    {
        public sealed class Surfaces
        {public Mesh Body,BodyLod,Hair,HairLod;}
        static readonly Dictionary<string,Surfaces> cache=new();
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void ResetForPlaySession()
        {
            // Enter Play Mode may skip domain reload. Meshes made by an edit-mode
            // fixture cannot be trusted across scene reload or unused-asset unload.
            Clear();
        }
        public static Surfaces Load(string id)
        {
            if(cache.TryGetValue(id,out var loaded))
            {
                if(loaded.Body!=null&&loaded.Body.vertexCount>0)return loaded;
                Release(loaded);cache.Remove(id);
            }
            var asset=Resources.Load<TextAsset>("Eternal/Actors/"+id+"/billboard.glb");if(asset==null)return null;
            byte[] data=asset.bytes;
            if(data.Length<28||BitConverter.ToUInt32(data,0)!=0x46546c67||BitConverter.ToUInt32(data,4)!=2||BitConverter.ToUInt32(data,8)!=data.Length)throw new InvalidOperationException("Invalid original GLB header: "+id);
            JObject root=null;int binaryStart=0,binaryLength=0;
            for(int offset=12;offset+8<=data.Length;)
            {
                int length=checked((int)BitConverter.ToUInt32(data,offset));uint type=BitConverter.ToUInt32(data,offset+4);offset+=8;
                if(length<0||offset>data.Length-length)throw new InvalidOperationException("Invalid GLB chunk bounds: "+id);
                if(type==0x4e4f534a)root=JObject.Parse(Encoding.UTF8.GetString(data,offset,length));
                if(type==0x004e4942){binaryStart=offset;binaryLength=length;}offset+=length;
            }
            if(root==null||binaryLength==0||root["extensionsRequired"] is JArray required&&required.Count>0)throw new InvalidOperationException("Unsupported original GLB: "+id);
            int Offset(int index,int components,int componentType,out int count,out int stride)
            {
                var accessor=(JObject)root["accessors"][index];var view=(JObject)root["bufferViews"][(int)accessor["bufferView"]];
                if((int)accessor["componentType"]!=componentType||accessor["sparse"]!=null||(int)(view["buffer"]??0)!=0)throw new InvalidOperationException("Unsupported original GLB accessor: "+id);
                count=(int)accessor["count"];int bytes=componentType==5126||componentType==5125?4:2;stride=(int)(view["byteStride"]??components*bytes);
                int start=(int)(view["byteOffset"]??0)+(int)(accessor["byteOffset"]??0),end=checked(start+Math.Max(0,count-1)*stride+components*bytes);
                if(count<=0||stride<components*bytes||start<0||end>binaryLength)throw new InvalidOperationException("Out-of-bounds original GLB accessor: "+id);return binaryStart+start;
            }
            Mesh Read(JObject meshData)
            {
                if(((JArray)meshData["primitives"]).Count!=1)throw new InvalidOperationException("Unsupported original GLB primitive count: "+id);
                var p=(JObject)meshData["primitives"][0];if((int)(p["mode"]??4)!=4)throw new InvalidOperationException("Expected original GLB triangles: "+id);
                var attributes=(JObject)p["attributes"];int pos=Offset((int)attributes["POSITION"],3,5126,out int count,out int stride);
                int texture=Offset((int)attributes["TEXCOORD_0"],2,5126,out int uvCount,out int uvStride);
                if(count!=uvCount)throw new InvalidOperationException("Original relief UV count mismatch: "+id);
                var vertices=new Vector3[count];var uv=new Vector2[count];
                for(int i=0;i<count;i++)
                {int v=pos+i*stride,t=texture+i*uvStride;vertices[i]=new Vector3(BitConverter.ToSingle(data,v),BitConverter.ToSingle(data,v+4),-BitConverter.ToSingle(data,v+8));uv[i]=new Vector2(BitConverter.ToSingle(data,t),BitConverter.ToSingle(data,t+4));}
                int component=(int)root["accessors"][(int)p["indices"]]["componentType"];
                if(component!=5123&&component!=5125)throw new InvalidOperationException("Unsupported original relief index encoding: "+id);
                int indicesOffset=Offset((int)p["indices"],1,component,out int indexCount,out int indexStride);if(indexCount%3!=0)throw new InvalidOperationException("Incomplete relief triangle: "+id);
                var indices=new int[indexCount];for(int i=0;i<indexCount;i++){int n=component==5123?BitConverter.ToUInt16(data,indicesOffset+i*indexStride):checked((int)BitConverter.ToUInt32(data,indicesOffset+i*indexStride));if(n<0||n>=count)throw new InvalidOperationException("Invalid relief triangle index: "+id);indices[i]=n;}
                for(int i=0;i<indices.Length;i+=3)(indices[i+1],indices[i+2])=(indices[i+2],indices[i+1]);
                var mesh=new Mesh{name=(string)meshData["name"],indexFormat=count>65535?IndexFormat.UInt32:IndexFormat.UInt16};mesh.vertices=vertices;mesh.uv=uv;mesh.triangles=indices;mesh.RecalculateNormals();
                // Shader remaps normalized source UVs to a foot-anchored pose.
                mesh.bounds=new Bounds(new Vector3(0,1,0),new Vector3(12,12,2));return mesh;
            }
            var result=new Surfaces();
            foreach(JObject m in root["meshes"])
            {
                string name=(string)m["name"];
                if(name.Contains("HairCards300LOD"))result.HairLod=Read(m);
                else if(name.Contains("HairCards600"))result.Hair=Read(m);
                else if(name.Contains("PaintedReliefLOD"))result.BodyLod=Read(m);
                else if(name.Contains("PaintedRelief"))result.Body=Read(m);
            }
            if(result.Body==null)throw new InvalidOperationException("Original relief body missing: "+id);cache[id]=result;return result;
        }
        public static void Clear()
        {foreach(var s in cache.Values)Release(s);cache.Clear();}
        static void Release(Surfaces s)
        {foreach(var mesh in new[]{s.Body,s.BodyLod,s.Hair,s.HairLod})if(mesh!=null){if(Application.isPlaying)UnityEngine.Object.Destroy(mesh);else UnityEngine.Object.DestroyImmediate(mesh);}}
    }
}
