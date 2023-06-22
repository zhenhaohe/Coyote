# /*
#  * Copyright (c) 2021, Systems Group, ETH Zurich
#  * All rights reserved.
#  *
#  * Redistribution and use in source and binary forms, with or without modification,
#  * are permitted provided that the following conditions are met:
#  *
#  * 1. Redistributions of source code must retain the above copyright notice,
#  * this list of conditions and the following disclaimer.
#  * 2. Redistributions in binary form must reproduce the above copyright notice,
#  * this list of conditions and the following disclaimer in the documentation
#  * and/or other materials provided with the distribution.
#  * 3. Neither the name of the copyright holder nor the names of its contributors
#  * may be used to endorse or promote products derived from this software
#  * without specific prior written permission.
#  *
#  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#  * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#  * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
#  * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#  * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#  * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  */
set command [lindex $argv 0]
set project [lindex $argv 1]
set device [lindex $argv 2]
set iprepoDir [lindex $argv 3]
set currentDir [lindex $argv 4]

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

set do_sim 0
set do_syn 0
set do_export 0
set do_cosim 0
set do_services 0

switch $command {
    "csim" {
        set do_sim 1
    }
    "syn" {
        set do_syn 1
    }
    "ip" {
        set do_syn 1
        set do_export 1
    }
    "cosim" {
        set do_syn 1
        set do_cosim 1
    }
    "services" {
        set do_syn 1
        set do_export 1
        set do_services 1
    }
    "all" {
        set do_sim 1
        set do_syn 1
        set do_export 1
        set do_cosim 1
    }
    default {
        puts "Unrecognized command: ${command}"
        exit
    }
}

open_project build_${project}

add_files $script_folder/${project}.cpp -cflags "-std=c++14"
add_files -tb $script_folder/tb_${project}.cpp -cflags "-std=c++14"  

set_top ${project}

open_solution sol1

if {$do_sim} {
    csim_design -clean
}

if {$do_syn} {
    set_part $device
    create_clock -period 4 -name default
    csynth_design
}

if {$do_export} {
    config_export -format ip_catalog -ipname "${project}" -display_name "${project}" -vendor "ethz.systems.fpga" -version "1.0"
    export_design
}

if ($do_services) {
    file mkdir ${iprepoDir}
    file delete -force ${iprepoDir}/build_${project}
    file copy -force ${currentDir}/build_${project}/sol1/impl/ip ${iprepoDir}/build_${project}
}


if ${do_cosim} {
    cosim_design
}

exit