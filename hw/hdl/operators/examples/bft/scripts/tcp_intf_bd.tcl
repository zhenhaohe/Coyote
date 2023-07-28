
################################################################
# This is a generated script based on design: tcp_intf
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

# ################################################################
# # Check if script is running in correct Vivado version.
# ################################################################
# set scripts_vivado_version 2022.1
# set current_vivado_version [version -short]

# if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
#    puts ""
#    catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

#    return 1
# }

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source tcp_intf_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

# set list_projs [get_projects -quiet]
# if { $list_projs eq "" } {
#    create_project project_1 build_tcp_intf -part $device
# }


# CHANGE DESIGN NAME HERE
variable design_name
set design_name tcp_intf

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

# set_property  ip_repo_paths [list $script_folder/build_tcp_openConReq $script_folder/build_tcp_openConResp $script_folder/build_tcp_openPort $script_folder/build_tcp_rxHandler $script_folder/build_tcp_txHandler] [current_project]


update_ip_catalog

# create_ip -name tcp_openConReq -vendor ethz.systems.fpga -library hls -version 1.0 -module_name tcp_openConReq_0
# create_ip -name tcp_openConResp -vendor ethz.systems.fpga -library hls -version 1.0 -module_name tcp_openConResp_0
# create_ip -name tcp_openPort -vendor ethz.systems.fpga -library hls -version 1.0 -module_name tcp_openPort_0
create_ip -name tcp_rxHandler -vendor ethz.systems.fpga -library hls -version 1.0 -module_name tcp_rxHandler_0
create_ip -name tcp_txHandler -vendor ethz.systems.fpga -library hls -version 1.0 -module_name tcp_txHandler_0
set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axis_data_fifo:2.0\
ethz.systems.fpga:hls:tcp_rxHandler:1.0\
ethz.systems.fpga:hls:tcp_txHandler:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: txHandler
proc create_hier_cell_txHandler { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_txHandler() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 axis_tcp_src

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_tx_meta

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_tx_stat

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tx_data

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tx_meta


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst ap_rst_n
  create_bd_pin -dir I -from 31 -to 0 -type data maxPkgWord

  # Create instance: tcp_txHandler_0, and set properties
  set tcp_txHandler_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:tcp_txHandler:1.0 tcp_txHandler_0 ]

  # Create instance: tx_cmd_fifo, and set properties
  set tx_cmd_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 tx_cmd_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {8} \
 ] $tx_cmd_fifo

  # Create instance: tx_data_fifo, and set properties
  set tx_data_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 tx_data_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.TDATA_NUM_BYTES {64} \
 ] $tx_data_fifo

  # Create instance: tx_meta_fifo, and set properties
  set tx_meta_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 tx_meta_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {4} \
 ] $tx_meta_fifo

  # Create instance: tx_sts_fifo, and set properties
  set tx_sts_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 tx_sts_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {8} \
 ] $tx_sts_fifo

  # Create instance: txp_tx_data_fifo, and set properties
  set txp_tx_data_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 txp_tx_data_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.TDATA_NUM_BYTES {64} \
 ] $txp_tx_data_fifo

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins tcp_txHandler_0/s_data_in] [get_bd_intf_pins tx_data_fifo/M_AXIS]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins tcp_txHandler_0/cmd_txHandler] [get_bd_intf_pins tx_cmd_fifo/M_AXIS]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins tcp_txHandler_0/s_axis_tcp_tx_status] [get_bd_intf_pins tx_sts_fifo/M_AXIS]
  connect_bd_intf_net -intf_net axis_tcp_src [get_bd_intf_pins axis_tcp_src] [get_bd_intf_pins txp_tx_data_fifo/M_AXIS]
  connect_bd_intf_net -intf_net tcp_txHandler_0_m_axis_tcp_tx_data [get_bd_intf_pins tcp_txHandler_0/m_axis_tcp_tx_data] [get_bd_intf_pins txp_tx_data_fifo/S_AXIS]
  connect_bd_intf_net -intf_net tcp_txHandler_0_m_axis_tcp_tx_meta [get_bd_intf_pins tcp_txHandler_0/m_axis_tcp_tx_meta] [get_bd_intf_pins tx_meta_fifo/S_AXIS]
  connect_bd_intf_net -intf_net tcp_tx_meta [get_bd_intf_pins tcp_tx_meta] [get_bd_intf_pins tx_meta_fifo/M_AXIS]
  connect_bd_intf_net -intf_net tcp_tx_stat [get_bd_intf_pins tcp_tx_stat] [get_bd_intf_pins tx_sts_fifo/S_AXIS]
  connect_bd_intf_net -intf_net tx_data [get_bd_intf_pins tx_data] [get_bd_intf_pins tx_data_fifo/S_AXIS]
  connect_bd_intf_net -intf_net tx_meta [get_bd_intf_pins tx_meta] [get_bd_intf_pins tx_cmd_fifo/S_AXIS]

  # Create port connections
  connect_bd_net -net ap_clk_1 [get_bd_pins ap_clk] [get_bd_pins tcp_txHandler_0/ap_clk] [get_bd_pins tx_cmd_fifo/s_axis_aclk] [get_bd_pins tx_data_fifo/s_axis_aclk] [get_bd_pins tx_meta_fifo/s_axis_aclk] [get_bd_pins tx_sts_fifo/s_axis_aclk] [get_bd_pins txp_tx_data_fifo/s_axis_aclk]
  connect_bd_net -net ap_rst_n_1 [get_bd_pins ap_rst_n] [get_bd_pins tcp_txHandler_0/ap_rst_n] [get_bd_pins tx_cmd_fifo/s_axis_aresetn] [get_bd_pins tx_data_fifo/s_axis_aresetn] [get_bd_pins tx_meta_fifo/s_axis_aresetn] [get_bd_pins tx_sts_fifo/s_axis_aresetn] [get_bd_pins txp_tx_data_fifo/s_axis_aresetn]
  connect_bd_net -net maxPkgWord_1 [get_bd_pins maxPkgWord] [get_bd_pins tcp_txHandler_0/maxPkgWord]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: rxHandler
proc create_hier_cell_rxHandler { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_rxHandler() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 axis_tcp_sink

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 rx_data

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 rx_meta

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_notify

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rd_package

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rx_meta


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst ap_rst_n

  # Create instance: rd_pkg_fifo, and set properties
  set rd_pkg_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 rd_pkg_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {4} \
 ] $rd_pkg_fifo

  # Create instance: rx_meta_fifo, and set properties
  set rx_meta_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 rx_meta_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {2} \
 ] $rx_meta_fifo

  # Create instance: rx_notification_fifo, and set properties
  set rx_notification_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 rx_notification_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {16} \
 ] $rx_notification_fifo

  # Create instance: s_data_out_fifo, and set properties
  set s_data_out_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 s_data_out_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.TDATA_NUM_BYTES {64} \
 ] $s_data_out_fifo

  # Create instance: s_meta_out_fifo, and set properties
  set s_meta_out_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 s_meta_out_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.TDATA_NUM_BYTES {8} \
 ] $s_meta_out_fifo

  # Create instance: tcp_rxHandler_0, and set properties
  set tcp_rxHandler_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:tcp_rxHandler:1.0 tcp_rxHandler_0 ]

  # Create instance: tcp_rx_data, and set properties
  set tcp_rx_data [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 tcp_rx_data ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.TDATA_NUM_BYTES {64} \
 ] $tcp_rx_data

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins rx_notification_fifo/M_AXIS] [get_bd_intf_pins tcp_rxHandler_0/s_axis_tcp_notification]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins rx_meta_fifo/M_AXIS] [get_bd_intf_pins tcp_rxHandler_0/s_axis_tcp_rx_meta]
  connect_bd_intf_net -intf_net Conn5 [get_bd_intf_pins tcp_rxHandler_0/s_axis_tcp_rx_data] [get_bd_intf_pins tcp_rx_data/M_AXIS]
  connect_bd_intf_net -intf_net axis_tcp_sink [get_bd_intf_pins axis_tcp_sink] [get_bd_intf_pins tcp_rx_data/S_AXIS]
  connect_bd_intf_net -intf_net rx_data [get_bd_intf_pins rx_data] [get_bd_intf_pins s_data_out_fifo/M_AXIS]
  connect_bd_intf_net -intf_net rx_meta [get_bd_intf_pins rx_meta] [get_bd_intf_pins s_meta_out_fifo/M_AXIS]
  connect_bd_intf_net -intf_net tcp_notify [get_bd_intf_pins tcp_notify] [get_bd_intf_pins rx_notification_fifo/S_AXIS]
  connect_bd_intf_net -intf_net tcp_rd_package [get_bd_intf_pins tcp_rd_package] [get_bd_intf_pins rd_pkg_fifo/M_AXIS]
  connect_bd_intf_net -intf_net tcp_rxHandler_0_m_axis_tcp_read_pkg [get_bd_intf_pins rd_pkg_fifo/S_AXIS] [get_bd_intf_pins tcp_rxHandler_0/m_axis_tcp_read_pkg]
  connect_bd_intf_net -intf_net tcp_rxHandler_0_s_data_out [get_bd_intf_pins s_data_out_fifo/S_AXIS] [get_bd_intf_pins tcp_rxHandler_0/s_data_out]
  connect_bd_intf_net -intf_net tcp_rxHandler_0_s_meta_out [get_bd_intf_pins s_meta_out_fifo/S_AXIS] [get_bd_intf_pins tcp_rxHandler_0/s_meta_out]
  connect_bd_intf_net -intf_net tcp_rx_meta [get_bd_intf_pins tcp_rx_meta] [get_bd_intf_pins rx_meta_fifo/S_AXIS]

  # Create port connections
  connect_bd_net -net ap_clk_1 [get_bd_pins ap_clk] [get_bd_pins rd_pkg_fifo/s_axis_aclk] [get_bd_pins rx_meta_fifo/s_axis_aclk] [get_bd_pins rx_notification_fifo/s_axis_aclk] [get_bd_pins s_data_out_fifo/s_axis_aclk] [get_bd_pins s_meta_out_fifo/s_axis_aclk] [get_bd_pins tcp_rxHandler_0/ap_clk] [get_bd_pins tcp_rx_data/s_axis_aclk]
  connect_bd_net -net ap_rst_n_1 [get_bd_pins ap_rst_n] [get_bd_pins rd_pkg_fifo/s_axis_aresetn] [get_bd_pins rx_meta_fifo/s_axis_aresetn] [get_bd_pins rx_notification_fifo/s_axis_aresetn] [get_bd_pins s_data_out_fifo/s_axis_aresetn] [get_bd_pins s_meta_out_fifo/s_axis_aresetn] [get_bd_pins tcp_rxHandler_0/ap_rst_n] [get_bd_pins tcp_rx_data/s_axis_aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: openPort_handler
proc create_hier_cell_openPort_handler { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_openPort_handler() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 open_port_cmd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 open_port_sts

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_listen_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_listen_rsp


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst ap_rst_n

  # Create instance: open_port_cmd_fifo, and set properties
  set open_port_cmd_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 open_port_cmd_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {32} \
   CONFIG.TDATA_NUM_BYTES {4} \
 ] $open_port_cmd_fifo

  # Create instance: open_port_sts_fifo, and set properties
  set open_port_sts_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 open_port_sts_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {32} \
   CONFIG.TDATA_NUM_BYTES {4} \
 ] $open_port_sts_fifo

  # Create instance: tcp_openPort_0, and set properties
  set tcp_openPort_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:tcp_openPort:1.0 tcp_openPort_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins tcp_listen_req] [get_bd_intf_pins tcp_openPort_0/m_axis_tcp_listen_port]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins open_port_cmd] [get_bd_intf_pins open_port_cmd_fifo/S_AXIS]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins tcp_listen_rsp] [get_bd_intf_pins tcp_openPort_0/s_axis_tcp_port_status]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins open_port_sts] [get_bd_intf_pins open_port_sts_fifo/M_AXIS]
  connect_bd_intf_net -intf_net open_port_cmd_fifo_M_AXIS [get_bd_intf_pins open_port_cmd_fifo/M_AXIS] [get_bd_intf_pins tcp_openPort_0/cmd]
  connect_bd_intf_net -intf_net tcp_openPort_0_sts [get_bd_intf_pins open_port_sts_fifo/S_AXIS] [get_bd_intf_pins tcp_openPort_0/sts]

  # Create port connections
  connect_bd_net -net ap_clk_1 [get_bd_pins ap_clk] [get_bd_pins open_port_cmd_fifo/s_axis_aclk] [get_bd_pins open_port_sts_fifo/s_axis_aclk] [get_bd_pins tcp_openPort_0/ap_clk]
  connect_bd_net -net ap_rst_n_1 [get_bd_pins ap_rst_n] [get_bd_pins open_port_cmd_fifo/s_axis_aresetn] [get_bd_pins open_port_sts_fifo/s_axis_aresetn] [get_bd_pins tcp_openPort_0/ap_rst_n]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: openCon_handler
proc create_hier_cell_openCon_handler { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_openCon_handler() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 open_con_cmd

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 open_con_sts

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_open_req

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_open_rsp


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst ap_rst_n

  # Create instance: open_con_cmd_fifo, and set properties
  set open_con_cmd_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 open_con_cmd_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {8} \
 ] $open_con_cmd_fifo

  # Create instance: open_con_sts_fifo, and set properties
  set open_con_sts_fifo [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 open_con_sts_fifo ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {64} \
   CONFIG.TDATA_NUM_BYTES {16} \
 ] $open_con_sts_fifo

  # Create instance: tcp_openConReq_0, and set properties
  set tcp_openConReq_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:tcp_openConReq:1.0 tcp_openConReq_0 ]

  # Create instance: tcp_openConResp_0, and set properties
  set tcp_openConResp_0 [ create_bd_cell -type ip -vlnv ethz.systems.fpga:hls:tcp_openConResp:1.0 tcp_openConResp_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net open_con_cmd [get_bd_intf_pins open_con_cmd] [get_bd_intf_pins open_con_cmd_fifo/S_AXIS]
  connect_bd_intf_net -intf_net open_con_cmd_fifo_M_AXIS [get_bd_intf_pins open_con_cmd_fifo/M_AXIS] [get_bd_intf_pins tcp_openConReq_0/cmd]
  connect_bd_intf_net -intf_net open_con_sts [get_bd_intf_pins open_con_sts] [get_bd_intf_pins open_con_sts_fifo/M_AXIS]
  connect_bd_intf_net -intf_net tcp_openConResp_0_sts [get_bd_intf_pins open_con_sts_fifo/S_AXIS] [get_bd_intf_pins tcp_openConResp_0/sts]
  connect_bd_intf_net -intf_net tcp_open_req [get_bd_intf_pins tcp_open_req] [get_bd_intf_pins tcp_openConReq_0/m_axis_tcp_open_connection]
  connect_bd_intf_net -intf_net tcp_open_rsp [get_bd_intf_pins tcp_open_rsp] [get_bd_intf_pins tcp_openConResp_0/s_axis_tcp_open_status]

  # Create port connections
  connect_bd_net -net ap_clk_1 [get_bd_pins ap_clk] [get_bd_pins open_con_cmd_fifo/s_axis_aclk] [get_bd_pins open_con_sts_fifo/s_axis_aclk] [get_bd_pins tcp_openConReq_0/ap_clk] [get_bd_pins tcp_openConResp_0/ap_clk]
  connect_bd_net -net ap_rst_n_1 [get_bd_pins ap_rst_n] [get_bd_pins open_con_cmd_fifo/s_axis_aresetn] [get_bd_pins open_con_sts_fifo/s_axis_aresetn] [get_bd_pins tcp_openConReq_0/ap_rst_n] [get_bd_pins tcp_openConResp_0/ap_rst_n]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set axis_tcp_sink [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 axis_tcp_sink ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $axis_tcp_sink

  set axis_tcp_src [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 axis_tcp_src ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $axis_tcp_src

#   set open_con_cmd [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 open_con_cmd ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    CONFIG.HAS_TKEEP {0} \
#    CONFIG.HAS_TLAST {0} \
#    CONFIG.HAS_TREADY {1} \
#    CONFIG.HAS_TSTRB {0} \
#    CONFIG.LAYERED_METADATA {undef} \
#    CONFIG.TDATA_NUM_BYTES {8} \
#    CONFIG.TDEST_WIDTH {0} \
#    CONFIG.TID_WIDTH {0} \
#    CONFIG.TUSER_WIDTH {0} \
#    ] $open_con_cmd

#   set open_con_sts [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 open_con_sts ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    ] $open_con_sts

#   set open_port_cmd [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 open_port_cmd ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    CONFIG.HAS_TKEEP {0} \
#    CONFIG.HAS_TLAST {0} \
#    CONFIG.HAS_TREADY {1} \
#    CONFIG.HAS_TSTRB {0} \
#    CONFIG.LAYERED_METADATA {undef} \
#    CONFIG.TDATA_NUM_BYTES {4} \
#    CONFIG.TDEST_WIDTH {0} \
#    CONFIG.TID_WIDTH {0} \
#    CONFIG.TUSER_WIDTH {0} \
#    ] $open_port_cmd

#   set open_port_sts [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 open_port_sts ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    ] $open_port_sts

  set rx_data [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 rx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $rx_data

  set rx_meta [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 rx_meta ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $rx_meta

#   set tcp_listen_req [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_listen_req ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    ] $tcp_listen_req

#   set tcp_listen_rsp [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_listen_rsp ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    CONFIG.HAS_TKEEP {0} \
#    CONFIG.HAS_TLAST {0} \
#    CONFIG.HAS_TREADY {1} \
#    CONFIG.HAS_TSTRB {0} \
#    CONFIG.LAYERED_METADATA {undef} \
#    CONFIG.TDATA_NUM_BYTES {1} \
#    CONFIG.TDEST_WIDTH {0} \
#    CONFIG.TID_WIDTH {0} \
#    CONFIG.TUSER_WIDTH {0} \
#    ] $tcp_listen_rsp

  set tcp_notify [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_notify ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {16} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tcp_notify

#   set tcp_open_req [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_open_req ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    ] $tcp_open_req

#   set tcp_open_rsp [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_open_rsp ]
#   set_property -dict [ list \
#    CONFIG.FREQ_HZ {250000000} \
#    CONFIG.HAS_TKEEP {0} \
#    CONFIG.HAS_TLAST {0} \
#    CONFIG.HAS_TREADY {1} \
#    CONFIG.HAS_TSTRB {0} \
#    CONFIG.LAYERED_METADATA {undef} \
#    CONFIG.TDATA_NUM_BYTES {16} \
#    CONFIG.TDEST_WIDTH {0} \
#    CONFIG.TID_WIDTH {0} \
#    CONFIG.TUSER_WIDTH {0} \
#    ] $tcp_open_rsp

  set tcp_rd_package [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rd_package ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $tcp_rd_package

  set tcp_rx_meta [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rx_meta ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {2} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tcp_rx_meta

  set tcp_tx_meta [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_tx_meta ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $tcp_tx_meta

  set tcp_tx_stat [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_tx_stat ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tcp_tx_stat

  set tx_data [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tx_data ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tx_data

  set tx_meta [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tx_meta ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $tx_meta


  # Create ports
  set ap_clk [ create_bd_port -dir I -type clk -freq_hz 250000000 ap_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {tx_data:tcp_tx_meta:axis_tcp_src:tcp_tx_stat:tcp_rx_meta:tcp_notify:axis_tcp_sink:tx_meta:tcp_rd_package:rx_data:rx_meta} \
   CONFIG.ASSOCIATED_RESET {ap_rst_n} \
 ] $ap_clk
  set ap_rst_n [ create_bd_port -dir I -type rst ap_rst_n ]
  set maxPkgWord [ create_bd_port -dir I -from 31 -to 0 -type data maxPkgWord ]

#   # Create instance: openCon_handler
#   create_hier_cell_openCon_handler [current_bd_instance .] openCon_handler

#   # Create instance: openPort_handler
#   create_hier_cell_openPort_handler [current_bd_instance .] openPort_handler

  # Create instance: rxHandler
  create_hier_cell_rxHandler [current_bd_instance .] rxHandler

  # Create instance: txHandler
  create_hier_cell_txHandler [current_bd_instance .] txHandler

  # Create interface connections
  connect_bd_intf_net -intf_net axis_tcp_sink_2 [get_bd_intf_ports axis_tcp_sink] [get_bd_intf_pins rxHandler/axis_tcp_sink]
#   connect_bd_intf_net -intf_net openCon_handler_open_con_sts [get_bd_intf_ports open_con_sts] [get_bd_intf_pins openCon_handler/open_con_sts]
#   connect_bd_intf_net -intf_net openCon_handler_tcp_open_req [get_bd_intf_ports tcp_open_req] [get_bd_intf_pins openCon_handler/tcp_open_req]
#   connect_bd_intf_net -intf_net openPort_handler_open_port_sts [get_bd_intf_ports open_port_sts] [get_bd_intf_pins openPort_handler/open_port_sts]
#   connect_bd_intf_net -intf_net openPort_handler_tcp_listen_req [get_bd_intf_ports tcp_listen_req] [get_bd_intf_pins openPort_handler/tcp_listen_req]
#   connect_bd_intf_net -intf_net open_con_cmd_1 [get_bd_intf_ports open_con_cmd] [get_bd_intf_pins openCon_handler/open_con_cmd]
#   connect_bd_intf_net -intf_net open_port_cmd_1 [get_bd_intf_ports open_port_cmd] [get_bd_intf_pins openPort_handler/open_port_cmd]
  connect_bd_intf_net -intf_net rxHandler_rx_data [get_bd_intf_ports rx_data] [get_bd_intf_pins rxHandler/rx_data]
  connect_bd_intf_net -intf_net rxHandler_rx_meta [get_bd_intf_ports rx_meta] [get_bd_intf_pins rxHandler/rx_meta]
  connect_bd_intf_net -intf_net rxHandler_tcp_rd_package [get_bd_intf_ports tcp_rd_package] [get_bd_intf_pins rxHandler/tcp_rd_package]
#   connect_bd_intf_net -intf_net tcp_listen_rsp_1 [get_bd_intf_ports tcp_listen_rsp] [get_bd_intf_pins openPort_handler/tcp_listen_rsp]
  connect_bd_intf_net -intf_net tcp_notify_1 [get_bd_intf_ports tcp_notify] [get_bd_intf_pins rxHandler/tcp_notify]
#   connect_bd_intf_net -intf_net tcp_open_rsp_1 [get_bd_intf_ports tcp_open_rsp] [get_bd_intf_pins openCon_handler/tcp_open_rsp]
  connect_bd_intf_net -intf_net tcp_rx_meta_1 [get_bd_intf_ports tcp_rx_meta] [get_bd_intf_pins rxHandler/tcp_rx_meta]
  connect_bd_intf_net -intf_net tcp_tx_stat_1 [get_bd_intf_ports tcp_tx_stat] [get_bd_intf_pins txHandler/tcp_tx_stat]
  connect_bd_intf_net -intf_net txHandler_axis_tcp_src [get_bd_intf_ports axis_tcp_src] [get_bd_intf_pins txHandler/axis_tcp_src]
  connect_bd_intf_net -intf_net txHandler_tcp_tx_meta [get_bd_intf_ports tcp_tx_meta] [get_bd_intf_pins txHandler/tcp_tx_meta]
  connect_bd_intf_net -intf_net tx_data_1 [get_bd_intf_ports tx_data] [get_bd_intf_pins txHandler/tx_data]
  connect_bd_intf_net -intf_net tx_meta_1 [get_bd_intf_ports tx_meta] [get_bd_intf_pins txHandler/tx_meta]

  # Create port connections
  connect_bd_net -net ap_clk_1 [get_bd_ports ap_clk] [get_bd_pins rxHandler/ap_clk] [get_bd_pins txHandler/ap_clk]
  connect_bd_net -net ap_rst_n_1 [get_bd_ports ap_rst_n] [get_bd_pins rxHandler/ap_rst_n] [get_bd_pins txHandler/ap_rst_n]
  connect_bd_net -net maxPkgWord_1 [get_bd_ports maxPkgWord] [get_bd_pins txHandler/maxPkgWord]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""

make_wrapper -files [get_files $build_dir/lynx/lynx.srcs/sources_1/bd/tcp_intf/tcp_intf.bd] -top
add_files -norecurse $build_dir/lynx/lynx.gen/sources_1/bd/tcp_intf/hdl/tcp_intf_wrapper.v
