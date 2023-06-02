##
## Default examples
##

if(NOT EXAMPLE EQUAL 0) 
    if(EXAMPLE STREQUAL "perf_host") #
        message("** Link benchmarks, host inititated. Force config.")
        set(EN_HLS 0)
        set(EN_MEM 0)
        set(EN_STRM 1) # Should work with MEM as well
        set(EN_MEM 0)  
        set(N_REGIONS 3)
    elseif(EXAMPLE STREQUAL "perf_fpga")
        message("** Link benchmarks, fpga initiated. Force config.")
        set(EN_HLS 0)
        set(EN_BPSS 1) 
        set(EN_STRM 1) # Should work with MEM as well
        set(EN_MEM 0) 
        set(EN_WB 1)
        set(N_CARD_AXI 2)
        set(N_STRM_AXI 2)
    elseif(EXAMPLE STREQUAL "gbm_dtrees")
        message("** Gradient boosting decision tree benchmarks. Force config.")
        set(EN_HLS 0)
        set(EN_STRM 1)
        set(EN_MEM 0)
    elseif(EXAMPLE STREQUAL "hyperloglog")
        message("** HyperLogLog cardinality estimation (HLS). Force config.")
        set(EN_HLS 1)
        set(EN_STRM 1)
        set(EN_MEM 0)
    elseif(EXAMPLE STREQUAL "perf_dram") 
        message("** Striping DRAM example. Force config.")
        set(N_REGIONS 4)
        set(EN_HLS 0)
        set(EN_STRM 0)
        set(EN_MEM 1)
        set(N_DDR_CHAN 2) # This depends on how many channels you actually have, u250 for instance can go up to 4
    elseif(EXAMPLE STREQUAL "perf_hbm") 
        message("** Striping HBM example. Force config.")
        set(N_REGIONS 4)
        set(EN_HLS 0)
        set(EN_STRM 0)
        set(EN_MEM 1)
    elseif(EXAMPLE STREQUAL "perf_rdma_host")
        message("** RDMA host perf. Force config.")
        set(EN_HLS 0)
        set(EN_BPSS 1)
        set(EN_STRM 1)
        set(EN_MEM 0)
        set(EN_RDMA_0 1)
    elseif(EXAMPLE STREQUAL "perf_rdma_card")
        message("** RDMA card perf. Force config.")
        set(EN_HLS 0)
        set(EN_BPSS 1)
        set(EN_STRM 0)
        set(EN_MEM 1)
        set(N_DDR_CHAN 1) # 
        set(EN_RDMA_0 1)
    elseif(EXAMPLE STREQUAL "perf_tcp")
        message("** TCP/IP benchmarks. Force config.")
        set(EN_HLS 0)
        set(EN_STRM 1)
        set(EN_TCP_0 1)
        add_subdirectory(hdl/operators/examples/perf_tcp/hls)
    elseif(EXAMPLE STREQUAL "rdma_regex")
        message("** RDMA regex. Force config.")
        set(EN_HLS 0)
        set(EN_BPSS 1)
        set(EN_STRM 0)
        set(EN_MEM 0)
        set(EN_RDMA_0 1)
    elseif(EXAMPLE STREQUAL "service_aes")
        message("** Coyote as a service (AES). Force config.")
        set(EN_HLS 0)
        set(EN_STRM 1)
        set(EN_MEM 0)
        set(N_REGIONS 1)
    elseif(EXAMPLE STREQUAL "service_reconfiguration")
        message("** Coyote as a service (Reconfiguration example). Force config.")
        set(EN_HLS 0)
        set(EN_STRM 1)
        set(EN_MEM 0)
        set(EN_PR 1)
        set(N_CONFIG 4)
        set(N_REGIONS 2)
    endif()
endif()