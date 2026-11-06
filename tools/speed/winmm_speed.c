/* 代理 winmm.dll: WINMM 全エクスポートを本物へ転送し、CG_SPEED>1 の cg.exe／cgmsv.exe で kernel32 の GetTickCount/Sleep の先頭を書き換えて加速する */
#include <windows.h>
#include <stdlib.h>
#include <string.h>

#define X(N) static FARPROC p_##N; \
    __attribute__((naked)) void N##_fwd(void) { __asm__ volatile("jmp *%0" :: "m"(p_##N)); }
#include "winmm_exports.h"
#undef X

static double g_n;
static LARGE_INTEGER g_freq, g_qpc0;
static DWORD g_base;
/* 本物の経過時間は QPC から取る（フック済みの GetTickCount は呼ばない） */
static DWORD WINAPI fast_tick(void) {
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);
    double real_ms = (double)(now.QuadPart - g_qpc0.QuadPart) * 1000.0 / (double)g_freq.QuadPart;
    return g_base + (DWORD)(real_ms * g_n);
}
static void WINAPI fast_sleep(DWORD ms) { SleepEx(ms == INFINITE ? ms : (DWORD)(ms / g_n), FALSE); }
/* 関数の先頭を jmp rel32 で置き換える（元の処理は呼ばないのでトランポリン不要） */
static void hook(void *target, void *repl) {
    BYTE *p = (BYTE *)target;
    DWORD old;
    if (!p || !VirtualProtect(p, 5, PAGE_EXECUTE_READWRITE, &old)) return;
    p[0] = 0xE9;
    *(DWORD *)(p + 1) = (DWORD)((BYTE *)repl - (p + 5));
    VirtualProtect(p, 5, old, &old);
    FlushInstructionCache(GetCurrentProcess(), p, 5);
}
BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r) {
    if (reason != DLL_PROCESS_ATTACH) return TRUE;
    DisableThreadLibraryCalls(h);
    char dir[MAX_PATH];
    UINT n = GetSystemDirectoryA(dir, MAX_PATH);  /* WoW64 では syswow64 を返す */
    if (!n || n > MAX_PATH - 16) return FALSE;
    strcpy(dir + n, "\\winmm.dll");
    HMODULE real = LoadLibraryA(dir);
    if (!real) return FALSE;
#define X(N) p_##N = GetProcAddress(real, #N);
#include "winmm_exports.h"
#undef X

    char exe[MAX_PATH], env[64];
    if (!GetModuleFileNameA(NULL, exe, MAX_PATH)) return TRUE;
    const char *base = strrchr(exe, '\\'); base = base ? base + 1 : exe;
    /* cgmsv.exe（殻付きの包装プログラム）はゲーム本体を自プロセス内で動かすので両方対象 */
    if (_stricmp(base, "cg.exe") && _stricmp(base, "cgmsv.exe")) return TRUE;
    if (!GetEnvironmentVariableA("CG_SPEED", env, sizeof env)) return TRUE;
    g_n = atof(env);
    if (!(g_n > 1.0)) return TRUE;
    HMODULE k = GetModuleHandleA("kernel32.dll");
    QueryPerformanceFrequency(&g_freq);
    QueryPerformanceCounter(&g_qpc0);
    g_base = GetTickCount();
    hook((void *)GetProcAddress(k, "GetTickCount"), (void *)fast_tick);
    hook((void *)GetProcAddress(k, "Sleep"), (void *)fast_sleep);
    return TRUE;
}
