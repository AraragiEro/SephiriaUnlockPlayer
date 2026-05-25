using System;
using HarmonyLib;
using Mirror;
using SephiriaUnlocker.Patches;
using UnityEngine;

namespace SephiriaUnlocker
{
    public class SephiriaUnlockerMod : HorayModBase
    {
        protected override void OnModLoaded()
        {
            try
            {
                var harmony = new Harmony("com.sephiria.unlockplayer");
                harmony.PatchAll();
                Debug.Log("[SephiriaUnlocker] All Harmony patches applied");

                ForceMaxConnections();
                MirrorPatches.StartMonitor();
            }
            catch (Exception ex)
            {
                Debug.LogError($"[SephiriaUnlocker] Failed to apply patches: {ex}");
            }
        }

        private static void ForceMaxConnections()
        {
            int target = 16;

            // 1. NetworkManager
            if (NetworkManager.singleton != null)
            {
                int before = NetworkManager.singleton.maxConnections;
                NetworkManager.singleton.maxConnections = target;
                Debug.Log($"[SephiriaUnlocker] INIT: NetworkManager.maxConnections {before} -> {target}");
            }
            else
                Debug.Log("[SephiriaUnlocker] INIT: NetworkManager.singleton is null");

            // 2. NetworkServer
            var nsField = typeof(NetworkServer).GetField("maxConnections",
                System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
            if (nsField != null)
            {
                int before = (int)nsField.GetValue(null);
                nsField.SetValue(null, target);
                Debug.Log($"[SephiriaUnlocker] INIT: NetworkServer.maxConnections {before} -> {target}");
            }
            else
                Debug.LogWarning("[SephiriaUnlocker] INIT: Could not find NetworkServer.maxConnections");

            // 4. Options — UI reads AllowedMultiplayerMember from here
            try
            {
                var optsType = Type.GetType("OptionsBinding, Assembly-CSharp");
                if (optsType != null)
                {
                    var instanceProp = optsType.GetProperty("Instance", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
                    var optionsProp = optsType.GetProperty("Options", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
                    if (instanceProp != null && optionsProp != null)
                    {
                        var instance = instanceProp.GetValue(null);
                        var options = optionsProp.GetValue(instance);
                        var setInt = options?.GetType().GetMethod("SetInt");
                        if (setInt != null)
                        {
                            setInt.Invoke(options, new object[] { "AllowedMultiplayerMember", 16 });
                            Debug.Log("[SephiriaUnlocker] INIT: Options.AllowedMultiplayerMember set to 16");
                        }
                    }
                }
            }
            catch (Exception ex) { Debug.LogWarning($"[SephiriaUnlocker] INIT: Options patch failed: {ex.Message}"); }
            if (Transport.active != null)
            {
                var t = Transport.active;
                foreach (var name in new[] { "maxConnections", "_maxConnections" })
                {
                    var f = t.GetType().GetField(name,
                        System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                    if (f != null)
                    {
                        int before = (int)f.GetValue(t);
                        f.SetValue(t, target);
                        Debug.Log($"[SephiriaUnlocker] INIT: Transport.{name} {before} -> {target}");
                        break;
                    }
                }
            }
            else
                Debug.Log("[SephiriaUnlocker] INIT: Transport.active is null (server not started yet, Transport.ServerStart postfix will catch it)");
        }

        protected override void OnModUnloaded()
        {
            Debug.Log("[SephiriaUnlocker] Mod unloaded");
        }
    }
}
