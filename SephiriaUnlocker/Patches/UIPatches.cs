using HarmonyLib;
using UnityEngine;

namespace SephiriaUnlocker.Patches
{
    /// <summary>
    /// Extends the in-game multiplayer member selector from 2-4 to 2-16.
    /// UI_HorizontalSelectionBox_MultiplayerNumber.OnEnable() normally sets:
    ///   box.numberOfElements = OptionsBinding.GetInt("AllowedMultiplayerMember", 4) - 1  (→ 3)
    /// This Postfix overrides it to 15 elements, giving the user options 2 through 16.
    /// </summary>
    public static class UIPatches
    {
        [HarmonyPatch(typeof(UI_HorizontalSelectionBox_MultiplayerNumber), "OnEnable")]
        [HarmonyPostfix]
        public static void PatchMultiplayerNumberOnEnable(UI_HorizontalSelectionBox_MultiplayerNumber __instance)
        {
            // __instance.box is public - set the element count to support up to 16 players
            __instance.box.numberOfElements = 15;
            Debug.Log("[SephiriaUnlocker] UI selector range extended to 2-16 players");
        }
    }
}
