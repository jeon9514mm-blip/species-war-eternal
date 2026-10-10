using System;
using System.Linq;

namespace Eternal.UnityMigration
{
    public static class NativeEquipmentLayout
    {
        // The original accessory record remains the necklace: importing never
        // discards or duplicates its item. Seven new positions start empty.
        public static readonly string[] Positions={"weapon","helmet","gloves","armor","boots","belt","ring1","ring2","bracelet","accessory"};
        public static readonly string[] ItemSlots={"weapon","helmet","gloves","armor","boots","belt","ring","bracelet","accessory"};
        public static bool Position(string slot)=>Positions.Contains(slot);
        public static string ItemSlot(string position)=>position=="ring1"||position=="ring2"?"ring":position;
        public static bool Fits(string itemSlot,string position)=>Position(position)&&ItemSlot(position)==itemSlot;
        public static string[] Matching(string itemSlot)=>Positions.Where(p=>Fits(itemSlot,p)).ToArray();
        public static string Label(string slot)=>slot switch
        {"weapon"=>"무기","helmet"=>"투구","gloves"=>"장갑","armor"=>"갑옷","boots"=>"부츠","belt"=>"벨트","ring"=>"반지","ring1"=>"반지 1","ring2"=>"반지 2","bracelet"=>"팔찌","accessory"=>"목걸이",_=>"재료"};
        public static string Category(string slot)=>slot=="weapon"?"weapon":slot=="ring"||slot=="ring1"||slot=="ring2"||slot=="bracelet"||slot=="accessory"?"accessory":"armor";
        public static string CostSlot(string slot)=>Category(slot)=="accessory"?"accessory":Category(slot)=="armor"?"armor":"weapon";
    }
}
