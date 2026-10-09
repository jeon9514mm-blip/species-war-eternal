using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        VisualElement huntMapTools;
        readonly Dictionary<float,Button> huntZoomButtons=new();
        void BuildHuntMapTools(VisualElement space)
        {
            if(!PersistentPlayer)return;
            huntMapTools=Row(root);huntMapTools.name="hunt-map-tools";huntMapTools.style.position=Position.Absolute;huntMapTools.style.left=18;huntMapTools.style.top=124;
            Button Circle(string label,System.Action action)
            {
                var b=Button(huntMapTools,label,action);b.style.minWidth=0;b.style.width=b.style.height=38;b.style.marginLeft=4;b.style.fontSize=10;b.style.paddingLeft=b.style.paddingRight=0;
                b.style.borderTopLeftRadius=b.style.borderTopRightRadius=b.style.borderBottomLeftRadius=b.style.borderBottomRightRadius=19;return b;
            }
            foreach(float value in new[]{1f,1.5f,2f,3f})
            {float zoom=value;var b=Circle("×"+value.ToString("0.#",System.Globalization.CultureInfo.InvariantCulture),()=>{feedback.SetHuntZoom(zoom);RefreshHuntMapTools();});b.name="hunt-zoom-"+value.ToString("0.#",System.Globalization.CultureInfo.InvariantCulture);b.tooltip=value==1?"전체 맵을 멀리서 보기":"같은 중심에서 ×"+value+" 확대";huntZoomButtons[value]=b;}
        }
        void RefreshHuntMapTools()
        {
            if(huntMapTools==null)return;huntMapTools.style.display=Raid==null&&modal.resolvedStyle.display==DisplayStyle.None?DisplayStyle.Flex:DisplayStyle.None;
            foreach(var pair in huntZoomButtons)pair.Value.style.backgroundColor=Mathf.Approximately(pair.Key,feedback.HuntZoom)?new Color(.29f,.35f,.28f):new Color(.10f,.14f,.15f);
        }
    }
}
