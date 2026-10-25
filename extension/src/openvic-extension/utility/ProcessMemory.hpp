#pragma once

#include <cstdint>

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
}
