###############################################################################
# build_pluto_win.tcl
#
# Builds the stock Pluto HDL project entirely from Vivado's TCL console
# on Windows — no Make, no WSL2 needed.
#
# Usage:
#   1. Open Vivado 2025.2
#   2. In the TCL Console at the bottom, type:
#        cd {D:/Xilinx_Workspace/2_Projects/analogdevices_hdl/projects/pluto}
#        source build_pluto_win.tcl
#   3. Wait 15-40 minutes
#
# Or from Windows command prompt:
#   cd D:\Xilinx_Workspace\2_Projects\analogdevices_hdl\projects\pluto
#   vivado -mode batch -source build_pluto_win.tcl
###############################################################################

# Skip the Vivado version check (repo targets 2025.1, we have 2025.2)
set ::env(ADI_IGNORE_VERSION_CHECK) 1

set hdl_root [file normalize [file join [pwd] "../.."]]
set project_dir [pwd]
puts "HDL root: $hdl_root"
puts "Project dir: $project_dir"

# ---- Step 1: Build interface definitions ----
# These must exist before any IP that references them.

set interfaces {
  interfaces
  axi_dmac/interfaces
}

foreach intf $interfaces {
  set intf_dir "$hdl_root/library/$intf"
  set intf_tcl "${intf_dir}/interfaces_ip.tcl"

  if {![file exists $intf_tcl]} {
    puts "WARN: Interface TCL not found: $intf_tcl"
    continue
  }

  # Check if already built (look for .xml files beyond source)
  set existing_xml [glob -nocomplain -directory $intf_dir "*.xml"]
  # interfaces_ip.tcl creates new bus definitions — safe to re-source

  puts "========================================"
  puts "Building interfaces: $intf"
  puts "========================================"

  cd $intf_dir
  source interfaces_ip.tcl
  cd $project_dir
}

# ---- Step 2: Build library IPs ----
# Order matters: dependencies must be built before dependents.
#
# Dependency chain:
#   util_cdc          (no deps)
#   util_axis_fifo    (depends on util_cdc)
#   axi_dmac          (depends on util_axis_fifo, util_cdc)
#   axi_ad9361        (no lib deps)
#   axi_tdd           (no lib deps)
#   util_cpack2       (no lib deps)
#   util_upack2       (no lib deps)

set libs {
  util_cdc
  util_axis_fifo
  axi_dmac
  axi_ad9361
  axi_tdd
  util_pack/util_cpack2
  util_pack/util_upack2
}

foreach lib $libs {
  set lib_dir "$hdl_root/library/$lib"
  set lib_name [file tail $lib]
  set ip_tcl "${lib_dir}/${lib_name}_ip.tcl"
  set component "${lib_dir}/component.xml"

  # Skip if already built
  if {[file exists $component]} {
    puts "SKIP: $lib_name (component.xml already exists)"
    continue
  }

  if {![file exists $ip_tcl]} {
    puts "ERROR: IP TCL not found: $ip_tcl"
    return -code error "Missing IP TCL: $ip_tcl"
  }

  puts "========================================"
  puts "Building library: $lib_name"
  puts "========================================"

  cd $lib_dir
  source ${lib_name}_ip.tcl
  cd $project_dir
}

# ---- Step 3: Build the Pluto project ----
puts "========================================"
puts "Building Pluto project"
puts "========================================"

cd $project_dir
source system_project.tcl

puts "========================================"
puts "BUILD COMPLETE"
puts "========================================"
puts "Bitstream: $project_dir/pluto.runs/impl_1/system_top.bit"
puts "XSA:       $project_dir/pluto.sdk/system_top.xsa"
