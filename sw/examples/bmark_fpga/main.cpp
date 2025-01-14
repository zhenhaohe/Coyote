#include <iostream>
#include <string>
#include <malloc.h>
#include <time.h> 
#include <sys/time.h>  
#include <chrono>
#include <fstream>
#include <fcntl.h>
#include <unistd.h>
#include <iomanip>
#ifdef EN_AVX
#include <x86intrin.h>
#endif
#include <boost/program_options.hpp>
#include <numeric>
#include <stdlib.h>

#include "cBench.hpp"
#include "cProc.hpp"

using namespace std;
using namespace fpga;

/* Def params */
constexpr auto const targetRegion = 0;
constexpr auto const nReps = 1;
constexpr auto const defSize = 128; // 2^7
constexpr auto const maxSize = 16 * 1024;
constexpr auto const defOper = 0; // 0: RD, 1: WR
constexpr auto const clkNs = 1000.0 / 300.0;
constexpr auto const nBenchRuns = 100;  

/**
 * @brief Benchmark API
 * 
 */
enum class BenchRegs : uint32_t {
    CTRL_REG = 0,
    DONE_REG = 1,
    TIMER_REG = 2,
    VADDR_REG = 3,
    LEN_REG = 4,
    PID_REG = 5,
    N_REPS_REG = 6,
    N_BEATS_REG = 7
};

enum class BenchOper : uint8_t {
    START_RD = 0x1,
    START_WR = 0x2
};

/**
 * @brief Average it out
 * 
 */
double vctr_avg(std::vector<double> const& v) {
    return 1.0 * std::accumulate(v.begin(), v.end(), 0LL) / v.size();
}

/**
 * @brief Throughput and latency tests, read and write
 * 
 */
int main(int argc, char *argv[])  
{
    // ---------------------------------------------------------------
    // Args 
    // ---------------------------------------------------------------

    // Read arguments
    boost::program_options::options_description programDescription("Options:");
    programDescription.add_options() 
        ("rdwr,w", boost::program_options::value<uint32_t>(), "Read (0) or a Write (1) operation");
    
    boost::program_options::variables_map commandLineArgs;
    boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
    boost::program_options::notify(commandLineArgs);

    uint32_t rdwr = defOper;
    if(commandLineArgs.count("rdwr") > 0) rdwr = commandLineArgs["rdwr"].as<uint32_t>();

    BenchOper oper = rdwr ? BenchOper::START_WR : BenchOper::START_RD;
    uint32_t n_reps = nReps;
    uint32_t n_pages = (maxSize + hugePageSize - 1) / hugePageSize;
    uint32_t curr_size = defSize;

    PR_HEADER("PARAMS");
    std::cout << "vFPGA ID: " << targetRegion << std::endl;
    std::cout << "Number of allocated pages: " << n_pages << std::endl;
    rdwr ? (std::cout << "Write operation" << std::endl) : (std::cout << "Read operation" << std::endl);

    // ---------------------------------------------------------------
    // Init 
    // ---------------------------------------------------------------

    // Handles and alloc
    cProc cproc(targetRegion, getpid());
    void* hMem = cproc.getMem({CoyoteAlloc::HUGE_2M, n_pages});

    // ---------------------------------------------------------------
    // Runs 
    // ---------------------------------------------------------------
    
    // Run Throughput
    auto benchmark_run = [&](cProc& cproc, const void* hMem, const BenchOper oper) {
        // Set params
        cproc.setCSR(reinterpret_cast<uint64_t>(hMem), static_cast<uint32_t>(BenchRegs::VADDR_REG));
        cproc.setCSR(curr_size, static_cast<uint32_t>(BenchRegs::LEN_REG));
        cproc.setCSR(cproc.getCpid(), static_cast<uint32_t>(BenchRegs::PID_REG));
        cproc.setCSR(n_reps, static_cast<uint32_t>(BenchRegs::N_REPS_REG));

        uint64_t n_beats = n_reps * ((curr_size + 64 - 1) / 64);
        cproc.setCSR(n_beats, static_cast<uint32_t>(BenchRegs::N_BEATS_REG));

        // Fire
        cproc.setCSR(static_cast<uint64_t>(oper), static_cast<uint32_t>(BenchRegs::CTRL_REG));

        while(cproc.getCSR(static_cast<uint32_t>(BenchRegs::DONE_REG)) < n_reps) ;
        return (double)(cproc.getCSR(static_cast<uint32_t>(BenchRegs::TIMER_REG))) * clkNs;
    };

    // Elapsed
    std::vector<double> time_bench_rd;
    std::vector<double> time_bench_wr;

    // Throughput run
    PR_HEADER("THROUGHPUT");

    while(curr_size <= maxSize) {
        for(int j = 0; j < nBenchRuns; j++) {
            time_bench_rd.emplace_back(benchmark_run(cproc, hMem, BenchOper::START_RD));
            time_bench_wr.emplace_back(benchmark_run(cproc, hMem, BenchOper::START_WR));
        }
        std::cout << std::setw(5) << curr_size << " [bytes], RD: " 
            << std::fixed << std::setprecision(2) << std::setw(5) << ((n_reps * 1024 * curr_size) / vctr_avg(time_bench_rd)) << " [MB/s], WR: "
            << std::setprecision(2) << std::setw(5) << ((n_reps * 1024 * curr_size) / vctr_avg(time_bench_wr)) << " [MB/s]" << std::endl;

        time_bench_rd.clear();
        time_bench_wr.clear();
        curr_size *= 2;
        cproc.clearCompleted();
    }
    

    n_reps = 1;
    curr_size = defSize;

    // Latency run
    PR_HEADER("LATENCY");

    while(curr_size <= maxSize) {
        for(int j = 0; j < nBenchRuns; j++) {
            time_bench_rd.emplace_back(benchmark_run(cproc, hMem, BenchOper::START_RD));
            time_bench_wr.emplace_back(benchmark_run(cproc, hMem, BenchOper::START_WR));
        }
        std::cout << std::setw(5) << curr_size << " [bytes], RD: " 
            << std::fixed << std::setprecision(2) << std::setw(5) << vctr_avg(time_bench_rd) << " [ns], WR: " 
            << std::setprecision(2) << std::setw(5) << vctr_avg(time_bench_rd) << " [ns]" << std::endl;

        time_bench_rd.clear();
        time_bench_wr.clear();
        curr_size *= 2;
        cproc.clearCompleted();
    }
    std::cout << "\n";

    // ---------------------------------------------------------------
    // Exit 
    // ---------------------------------------------------------------
    
    return EXIT_SUCCESS;
}
