using System.Reflection;
using HarmonyLib;
using Mirror;
using UnityEngine;

namespace SephiriaUnlocker.Patches
{
    public static class MirrorPatches
    {
        private const int TARGET = 16;
        private static bool _transportPatched;

        // ── Auto-poll: check every 2s until transport starts ──
        private static GameObject _monitorGO;

        internal static void StartMonitor()
        {
            if (_monitorGO != null) return;
            _monitorGO = new GameObject("SephiriaUnlocker_Monitor");
            _monitorGO.hideFlags = HideFlags.HideAndDontSave;
            _monitorGO.AddComponent<MonitorBehaviour>();
            Object.DontDestroyOnLoad(_monitorGO);
        }

        private class MonitorBehaviour : MonoBehaviour
        {
            private float _timer;
            private int _attempts;

            private void Update()
            {
                _timer += Time.deltaTime;
                if (_timer < 2f) return;
                _timer = 0f;
                _attempts++;

                if (ForceTransportLimit())
                {
                    Debug.Log($"[SephiriaUnlocker] MONITOR: transport patched after {_attempts} attempts");
                    Destroy(gameObject);
                }
                else if (_attempts >= 10)
                {
                    Debug.LogWarning("[SephiriaUnlocker] MONITOR: transport never became active after 20s");
                    Destroy(gameObject);
                }
            }
        }

        internal static bool ForceTransportLimit()
        {
            if (_transportPatched) return true;
            if (Transport.active == null) return false;

            var transport = Transport.active;
            // FizzySteamworks wraps a NextServer/LegacyServer in a "server" field
            var serverField = transport.GetType().GetField("server",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
            if (serverField == null)
            {
                Debug.LogWarning($"[SephiriaUnlocker] TRANSPORT: no 'server' field on {transport.GetType().Name}");
                return false;
            }

            var server = serverField.GetValue(transport);
            if (server == null) return false;

            foreach (var name in new[] { "maxConnections", "_maxConnections" })
            {
                var f = server.GetType().GetField(name,
                    BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (f != null)
                {
                    int before = (int)f.GetValue(server);
                    f.SetValue(server, TARGET);
                    Debug.Log($"[SephiriaUnlocker] TRANSPORT '{server.GetType().Name}.{name}': {before} -> {TARGET}");
                    _transportPatched = true;
                    return true;
                }
            }
            Debug.LogWarning($"[SephiriaUnlocker] TRANSPORT: no maxConnections on {server.GetType().Name}");
            return false;
        }

        // ── Connection: log transport count vs max ──
        [HarmonyPatch(typeof(NetworkManager), "OnServerConnect")]
        [HarmonyPostfix]
        internal static void LogConnection()
        {
            string transportInfo = "?";
            try
            {
                if (Transport.active != null)
                {
                    var sf = Transport.active.GetType().GetField("server",
                        BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
                    if (sf != null)
                    {
                        var srv = sf.GetValue(Transport.active);
                        if (srv != null)
                        {
                            var t = srv.GetType();
                            var maxField = t.GetField("maxConnections",
                                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                            // Try to get count from any collection field
                            int count = -1, max = -1;
                            if (maxField != null) max = (int)maxField.GetValue(srv);
                            foreach (var fn in new[] { "connToMirrorID", "steamToMirrorIds" })
                            {
                                var cf = t.GetField(fn, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                                if (cf != null)
                                {
                                    var coll = cf.GetValue(srv);
                                    if (coll != null)
                                    {
                                        // Use reflection to get Count property
                                        var countProp = coll.GetType().GetProperty("Count");
                                        if (countProp != null) count = (int)countProp.GetValue(coll);
                                    }
                                }
                            }
                            transportInfo = $"{count}/{max}";
                        }
                    }
                }
            }
            catch { transportInfo = "error"; }

            Debug.Log($"[SephiriaUnlocker] CONNECT: Mirror {NetworkServer.connections.Count}/{NetworkServer.maxConnections} | Transport {transportInfo}");
        }

        // ── StartServer/StartHost fallback ──
        [HarmonyPatch(typeof(NetworkManager), nameof(NetworkManager.StartServer))]
        [HarmonyPrefix]
        internal static bool PatchStartServer(NetworkManager __instance)
        {
            __instance.maxConnections = TARGET;
            return true;
        }

        [HarmonyPatch(typeof(NetworkManager), nameof(NetworkManager.StartHost))]
        [HarmonyPrefix]
        internal static bool PatchStartHost(NetworkManager __instance)
        {
            __instance.maxConnections = TARGET;
            return true;
        }
    }
}
