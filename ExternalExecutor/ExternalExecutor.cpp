#pragma once
#include "Bridge.hpp"

#include <iostream>
#include <Windows.h>
#include <string>
#include <vector>
#include <thread>

#include "Utils/Process.hpp"
#include "Utils/Instance.hpp"
#include "Utils/Bytecode.hpp"

std::string GetLuaCode(DWORD pid, int idx) {
    HMODULE hModule = NULL;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        (LPCWSTR)&GetLuaCode, &hModule);

    HRSRC resourceHandle = FindResourceW(hModule, MAKEINTRESOURCEW(idx), RT_RCDATA);
    if (resourceHandle == NULL)
    {
        return "";
    }

    HGLOBAL loadedResource = LoadResource(hModule, resourceHandle);
    if (loadedResource == NULL)
    {
        return "";
    }

    DWORD size = SizeofResource(hModule, resourceHandle);
    void* data = LockResource(loadedResource);

    std::string code = std::string(static_cast<char*>(data), size);
    size_t pos = code.find("%-PROCESS-ID-%");
    if (pos != std::string::npos) {
        code.replace(pos, 14, std::to_string(pid));
    }

    return code;
}

int main()
{
    std::thread(StartBridge).detach();
    std::vector<DWORD> pids = Process::GetProcessID();
    for (DWORD pid : pids) {
        uintptr_t base = Process::GetModuleBase(pid);
        Instance Datamodel = FetchDatamodel(base, pid);

        size_t inits;
        std::string initLua = GetLuaCode(pid, 1);
        std::vector<char> initb = Bytecode::Sign(Bytecode::Compile(initLua), inits);

        if (Datamodel.Name() == "Ugc") {
            Instance CoreGui = Datamodel.FindFirstChild("CoreGui");
            Instance RobloxGui = CoreGui.FindFirstChild("RobloxGui");
            Instance Modules = RobloxGui.FindFirstChild("Modules");
            Instance PlayerList = Modules.FindFirstChild("PlayerList");
            Instance PlmModule = PlayerList.FindFirstChild("PlayerListManager");

            Instance CorePackages = Datamodel.FindFirstChild("CorePackages");
            Instance Packages = CorePackages.FindFirstChild("Packages");
            Instance Index = Packages.FindFirstChild("_Index");
            Instance Cm2D1 = Index.FindFirstChild("CollisionMatchers2D");
            Instance Cm2D2 = Cm2D1.FindFirstChild("CollisionMatchers2D");
            Instance Jest = Cm2D2.FindFirstChild("Jest");

            WriteMemory<BYTE>(base + Offsets::EnableLoadModule, 1, pid);
            WriteMemory<uintptr_t>(PlmModule.GetAddress() + 0x8, Jest.GetAddress(), pid);
            
            auto revert1 = Jest.SetScriptBytecode(initb, inits);
            HWND hwnd = Process::GetWindowsProcess(pid);
            HWND old = GetForegroundWindow();
            while (GetForegroundWindow() != hwnd) {
                SetForegroundWindow(hwnd);
                Sleep(1);
            }
            keybd_event(VK_ESCAPE, MapVirtualKey(VK_ESCAPE, 0), KEYEVENTF_SCANCODE, 0);
            keybd_event(VK_ESCAPE, MapVirtualKey(VK_ESCAPE, 0), KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP, 0);

            CoreGui.WaitForChild("ExternalExecutor");

            SetForegroundWindow(old);
            WriteMemory<uintptr_t>(PlmModule.GetAddress() + 0x8, PlmModule.GetAddress(), pid);
            revert1();
        }
        else {
            std::thread([=]() {
                Instance Datamodel = Instance(0, pid);
                while (true) {
                    Datamodel = FetchDatamodel(base, pid);
                    if (Datamodel.Name() == "Ugc")
                        break;
                    Sleep(250);
                }
                Instance CoreGui = Datamodel.FindFirstChild("CoreGui");
                Instance RobloxGui = CoreGui.FindFirstChild("RobloxGui");
                Instance Modules = RobloxGui.FindFirstChild("Modules");
                Instance InitModule = Modules.FindFirstChild("AvatarEditorPrompts");

                WriteMemory<BYTE>(base + Offsets::EnableLoadModule, 1, pid);
                auto revert1 = InitModule.SetScriptBytecode(initb, inits);

                CoreGui.WaitForChild("ExternalExecutor");

                revert1();
                }).detach();
        }
    }
}

std::string Convert(const wchar_t* wideStr) {
    if (!wideStr) return "";
    int size_needed = WideCharToMultiByte(
        CP_UTF8, 0, wideStr, -1, nullptr, 0, nullptr, nullptr
    );
    if (size_needed == 0) return "";
    std::string result(size_needed, 0);
    WideCharToMultiByte(
        CP_UTF8, 0, wideStr, -1, &result[0], size_needed, nullptr, nullptr
    );
    if (!result.empty() && result.back() == '\0') {
        result.pop_back();
    }
    return result;
}

bool Injected = false;
extern "C" __declspec(dllexport) void Nuke(const wchar_t* input) {
    if (!Injected) {
        Injected = true;
        FILE* conOut;
        AllocConsole();
        SetConsoleTitleA("ExternalExecutor");
        freopen_s(&conOut, "CONOUT$", "w", stdout);
        freopen_s(&conOut, "CONOUT$", "w", stderr);
        main();
    }
    std::string source = Convert(input);
    if (source.length() >= 1) {
        Execute(source);
    }
}