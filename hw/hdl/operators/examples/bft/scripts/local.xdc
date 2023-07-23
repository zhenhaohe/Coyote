# pblock for PR dynamic user design
create_pblock pblock_inst_auth_role_rx
add_cells_to_pblock [get_pblocks pblock_inst_auth_role_rx] [get_cells -quiet [list inst_dynamic/inst_user_wrapper_0/inst_user_c0_0/bench_role_inst/auth_role_wrapper_rx/auth_role]]
resize_pblock [get_pblocks pblock_inst_auth_role_rx] -add CLOCKREGION_X0Y8:CLOCKREGION_X3Y11

# pblock for PR dynamic user design
create_pblock pblock_inst_auth_role_tx
add_cells_to_pblock [get_pblocks pblock_inst_auth_role_tx] [get_cells -quiet [list inst_dynamic/inst_user_wrapper_0/inst_user_c0_0/bench_role_inst/auth_role_wrapper_tx/auth_role]]
resize_pblock [get_pblocks pblock_inst_auth_role_tx] -add CLOCKREGION_X4Y8:CLOCKREGION_X7Y11