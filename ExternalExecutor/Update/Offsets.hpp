#pragma once
#include <Windows.h>

namespace Offsets {
	const uintptr_t EnableLoadModule = 0x5F2F9A0;

	inline constexpr uintptr_t FakeDataModelPointer = 0x70B1EF8;
	inline constexpr uintptr_t FakeDataModelToDataModel = 0x1C0;

	inline constexpr uintptr_t Children = 0x68;
	inline constexpr uintptr_t ChildrenEnd = 0x8;
	inline constexpr uintptr_t Name = 0x88;
	inline constexpr uintptr_t Value = 0xD8;

	inline constexpr uintptr_t ClassDescriptor = 0x18;
	inline constexpr uintptr_t ClassDescriptorToClassName = 0x8;

	inline constexpr uintptr_t LocalScriptByteCode = 0x1B0;
	inline constexpr uintptr_t ModuleScriptByteCode = 0x158;

	inline constexpr uintptr_t ScriptContext = 0x3D0;
	inline constexpr uintptr_t RequireBypass = 0x828;
}
