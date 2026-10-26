#include "ProcessMemory.hpp"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
// clang-format off
#include <psapi.h>
#include <tlhelp32.h>
// clang-format on
#pragma comment(lib, "psapi.lib")
#elif defined(__linux__)
#include <cstdio>
#include <cstring>
#endif

#include <algorithm>
#include <thread>
#include <unordered_map>

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

#if defined(_WIN32)
namespace {
	struct ProcessorTimes {
		LARGE_INTEGER idle, kernel, user, dpc, interrupt;
		ULONG interrupt_count;
	};
	using NtQuerySystemInformationFn = LONG(WINAPI*)(ULONG, PVOID, ULONG, PULONG);
	using GetThreadDescriptionFn = HRESULT(WINAPI*)(HANDLE, PWSTR*);

	std::uint64_t file_time_to_u64(FILETIME const& time) {
		return (static_cast<std::uint64_t>(time.dwHighDateTime) << 32) | time.dwLowDateTime;
	}

	std::string thread_name(HANDLE thread) {
		static const GetThreadDescriptionFn get_description =
			reinterpret_cast<GetThreadDescriptionFn>(GetProcAddress(GetModuleHandleA("kernel32.dll"), "GetThreadDescription"));
		if (get_description == nullptr) {
			return {};
		}
		PWSTR wide = nullptr;
		if (FAILED(get_description(thread, &wide)) || wide == nullptr) {
			return {};
		}
		std::string result;
		const int length = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
		if (length > 1) {
			result.resize(static_cast<std::size_t>(length - 1));
			WideCharToMultiByte(CP_UTF8, 0, wide, -1, result.data(), length, nullptr, nullptr);
		}
		LocalFree(wide);
		return result;
	}
}
#endif

CpuUsage OpenVic::sample_cpu_usage() {
	CpuUsage result;
	result.logical_cores = static_cast<int>(std::max(1u, std::thread::hardware_concurrency()));
#if defined(_WIN32)
	static bool has_previous = false;
	static std::vector<ProcessorTimes> previous_cores;
	static std::uint64_t previous_process = 0, previous_wall = 0;
	static std::unordered_map<DWORD, std::uint64_t> previous_threads;
	static const NtQuerySystemInformationFn query = reinterpret_cast<NtQuerySystemInformationFn>(
		GetProcAddress(GetModuleHandleA("ntdll.dll"), "NtQuerySystemInformation")
	);

	LARGE_INTEGER counter, frequency;
	QueryPerformanceCounter(&counter);
	QueryPerformanceFrequency(&frequency);
	const std::uint64_t wall =
		static_cast<std::uint64_t>(static_cast<double>(counter.QuadPart) / static_cast<double>(frequency.QuadPart) * 1.0e7);

	std::vector<ProcessorTimes> cores(static_cast<std::size_t>(result.logical_cores));
	bool cores_valid = false;
	if (query != nullptr) {
		ULONG returned = 0;
		cores_valid = query(8, cores.data(), static_cast<ULONG>(cores.size() * sizeof(ProcessorTimes)), &returned) >= 0;
		if (cores_valid) {
			cores.resize(returned / sizeof(ProcessorTimes));
		}
	}

	FILETIME creation, exit_time, kernel, user;
	std::uint64_t process_time = 0;
	if (GetProcessTimes(GetCurrentProcess(), &creation, &exit_time, &kernel, &user)) {
		process_time = file_time_to_u64(kernel) + file_time_to_u64(user);
	}

	const double wall_delta = static_cast<double>(wall - previous_wall);
	std::unordered_map<DWORD, std::uint64_t> current_threads;
	HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
	if (snapshot != INVALID_HANDLE_VALUE) {
		THREADENTRY32 entry {};
		entry.dwSize = sizeof(entry);
		const DWORD pid = GetCurrentProcessId();
		for (BOOL ok = Thread32First(snapshot, &entry); ok; ok = Thread32Next(snapshot, &entry)) {
			if (entry.th32OwnerProcessID != pid) {
				continue;
			}
			HANDLE thread = OpenThread(THREAD_QUERY_LIMITED_INFORMATION, FALSE, entry.th32ThreadID);
			if (thread == nullptr) {
				continue;
			}
			FILETIME thread_creation, thread_exit, thread_kernel, thread_user;
			if (GetThreadTimes(thread, &thread_creation, &thread_exit, &thread_kernel, &thread_user)) {
				const std::uint64_t time = file_time_to_u64(thread_kernel) + file_time_to_u64(thread_user);
				current_threads[entry.th32ThreadID] = time;
				if (has_previous && wall_delta > 0.0) {
					auto const it = previous_threads.find(entry.th32ThreadID);
					if (it != previous_threads.end()) {
						CpuUsage::Thread info;
						info.id = entry.th32ThreadID;
						info.percent = static_cast<double>(time - it->second) / wall_delta * 100.0;
						if (info.percent >= 0.5) {
							info.name = thread_name(thread);
						}
						result.threads.push_back(std::move(info));
					}
				}
			}
			CloseHandle(thread);
		}
		CloseHandle(snapshot);
	}

	if (has_previous && wall_delta > 0.0) {
		result.valid = true;
		result.process_cores = static_cast<double>(process_time - previous_process) / wall_delta;
		result.process_percent = result.process_cores / result.logical_cores * 100.0;
		if (cores_valid && cores.size() == previous_cores.size()) {
			double busy_sum = 0.0;
			for (std::size_t i = 0; i < cores.size(); i++) {
				const double total = static_cast<double>(cores[i].kernel.QuadPart - previous_cores[i].kernel.QuadPart)
					+ static_cast<double>(cores[i].user.QuadPart - previous_cores[i].user.QuadPart);
				const double idle = static_cast<double>(cores[i].idle.QuadPart - previous_cores[i].idle.QuadPart);
				const double busy = total > 0.0 ? std::clamp((total - idle) / total * 100.0, 0.0, 100.0) : 0.0;
				result.core_percent.push_back(busy);
				busy_sum += busy;
			}
			result.system_percent = cores.empty() ? 0.0 : busy_sum / static_cast<double>(cores.size());
		}
		std::sort(result.threads.begin(), result.threads.end(), [](CpuUsage::Thread const& a, CpuUsage::Thread const& b) {
			return a.percent > b.percent;
		});
		for (CpuUsage::Thread const& thread : result.threads) {
			if (thread.percent > 10.0) {
				result.busy_threads++;
			}
		}
	}

	if (cores_valid) {
		previous_cores = std::move(cores);
	}
	previous_process = process_time;
	previous_wall = wall;
	previous_threads = std::move(current_threads);
	has_previous = true;
#endif
	return result;
}
