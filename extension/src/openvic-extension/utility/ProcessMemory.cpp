#include "ProcessMemory.hpp"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
// clang-format off
#include <psapi.h>
// clang-format on
#pragma comment(lib, "psapi.lib")
#elif defined(__linux__)
#include <cstdio>
#include <cstring>
#endif

using namespace OpenVic;

ProcessMemory OpenVic::get_process_memory() {
	ProcessMemory result;
#if defined(_WIN32)
	PROCESS_MEMORY_COUNTERS_EX counters {};
	counters.cb = sizeof(counters);
	if (GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&counters), sizeof(counters))) {
		result.working_set = counters.WorkingSetSize;
		result.peak_working_set = counters.PeakWorkingSetSize;
		result.private_bytes = counters.PrivateUsage;
		result.valid = true;
	}
#elif defined(__linux__)
	if (std::FILE* file = std::fopen("/proc/self/status", "r")) {
		char line[256];
		while (std::fgets(line, sizeof(line), file)) {
			unsigned long long kilobytes = 0;
			if (std::sscanf(line, "VmRSS: %llu kB", &kilobytes) == 1) {
				result.working_set = kilobytes * 1024;
				result.valid = true;
			} else if (std::sscanf(line, "VmHWM: %llu kB", &kilobytes) == 1) {
				result.peak_working_set = kilobytes * 1024;
			} else if (std::sscanf(line, "VmData: %llu kB", &kilobytes) == 1) {
				result.private_bytes = kilobytes * 1024;
			}
		}
		std::fclose(file);
	}
#endif
	return result;
}
