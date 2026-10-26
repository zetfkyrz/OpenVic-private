#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace OpenVic {
	/* Memory the operating system gives to the game process (the Godot monitors only see what Godot allocates itself,
	 * not the simulation, the textures of the driver or the DLLs). All values are in bytes, 0 if they are not known. */
	struct ProcessMemory {
		std::uint64_t working_set = 0; // memory in RAM now
		std::uint64_t peak_working_set = 0;
		std::uint64_t private_bytes = 0; // committed memory of the process (what a leak grows)
		bool valid = false;
	};

	ProcessMemory get_process_memory();

	/* How much of the processor the game uses (a sample since the previous call; the first call has nothing to compare with). */
	struct CpuUsage {
		struct Thread {
			std::uint64_t id = 0;
			std::string name;
			double percent = 0.0; // of one core
		};
		bool valid = false;
		int logical_cores = 0;
		double system_percent = 0.0; // all processes, of all cores
		std::vector<double> core_percent; // every logical core, all processes
		double process_percent = 0.0; // this process, of all cores
		double process_cores = 0.0; // this process in whole cores (2.5 = two and a half cores are busy)
		int busy_threads = 0; // threads that use more than a tenth of a core
		std::vector<Thread> threads; // the busiest first
	};

	CpuUsage sample_cpu_usage();
}
