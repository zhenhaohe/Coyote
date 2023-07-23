from os import error, listdir, name, terminal_size
from os.path import isfile, join
from numpy import average, mean, std

import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import matplotlib.ticker as ticker

def plot_clustered_bars(title, x_datas, y_datas, y_labels):
   
    width = 1/len(y_datas)  # the width of the bars
    from itertools import chain
    ticks = list(np.unique(np.concatenate(x_datas)))
    fig, ax = plt.subplots(figsize=(10,4))

    for i, (x, y, y_label) in enumerate(zip(x_datas, y_datas, y_labels)):
        ax.bar(x + (i - len(y_datas)/2)*width, y, width, label=y_label)

    plt.grid(axis='y')
    # Add some text for labels, title and custom x-axis tick labels, etc.
    ax.set_ylabel('Latency [us]')
    #ax.set_title(title)
    ax.set_xlabel('Message Size [KB]')
    ax.set_xticks(ticks)
    ax.legend()
    plt.show()
    #plt.savefig(f"{title}.png")


def plot_lines(title, x_datas, y_datas, y_series_labels, y_styles=None, logx=True, logy=True, x_label='Message Size', y_label='Latency [us]', y_errors=None, legend_loc=None, throughput=False):
    if not(y_styles):
        y_styles = [None for _ in range(len(y_series_labels))]
    
    if not(y_errors):
        y_errors = [None for _ in range(len(y_series_labels))]

    fig, ax = plt.subplots(figsize=(9,6))
    series  = []
    for x, y, y_series_label, y_style, y_error in zip(x_datas, y_datas, y_series_labels, y_styles, y_errors):
        if y_style:
            if not y_error is None:
                series.append(ax.errorbar(x, y,  yerr = y_error, fmt=y_style, label=y_series_label, capsize=4.0, linewidth=3, markersize=8, markeredgewidth=3))
            else:
                line, = ax.plot(x, y, y_style, label=y_series_label, linewidth=3, markersize=8, markeredgewidth=3)
                series.append(line)
        else:
            if not y_error is None:
                series.append(ax.errorbar(x, y,  yerr = y_error, fmt=y_style, label=y_series_label, capsize=4.0, linewidth=3, markersize=8, markeredgewidth=3))
            else:
                line, = ax.plot(x, y, label=y_series_label, linewidth=3, markersize=8, markeredgewidth=3)
                series.append(line)

    plt.grid(axis='y')
    # Add some text for labels, title and custom x-axis tick labels, etc.
    if throughput:
        ax.set_ylabel('Throughput [Gbps]', fontsize=20)
        ax.axis(ymin=0,ymax=100)
    else:
        ax.set_ylabel(y_label,  fontsize=20)
        ax.axis(ymin=0)
    ax.set_title(title,  fontsize=20)
    if logy:
        ax.set_yscale('log')
    
    if logx:
        ax.set_xscale('log', base=2)
        
    if legend_loc is None :
        if logy:
            ax.legend(series, y_series_labels, loc="lower right", handlelength=4)
        else:
            ax.legend(series, y_series_labels, loc="upper left", handlelength=4)
    else:
        ax.legend(    series, y_series_labels, loc=legend_loc, fontsize=14, handlelength=4)

    if x_label == "Message Size":
        ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda y, _: sizeof_fmt(y)))
    plt.xticks(rotation=0, fontsize=18)
    plt.yticks(fontsize=18)
    ax.set_xlabel(x_label, fontsize=20)
    # plt.show()
    plt.savefig(f"{title}.png", format='png', bbox_inches='tight')

def plot_lines2(title, x_datas, y_datas, y_labels, y_styles=None, logx=True, logy=True, y_errors=None):
    if not(y_styles):
        y_styles = [None for _ in range(len(y_labels))]
    
    if not(y_errors):
        y_errors = [None for _ in range(len(y_labels))]

    fig, ax = plt.subplots(figsize=(7,6))

    for x, y, y_label, y_style, y_error in zip(x_datas, y_datas, y_labels, y_styles, y_errors):
        if y_style:
            ax.plot(x, y, y_style, label=y_label)
        else:
            ax.plot(x, y, label=y_label)
        
        if y_error is not None:
            ax.fill_between(x,y-y_error,y+y_error,alpha=.1)

    plt.grid(axis='y')
    # Add some text for labels, title and custom x-axis tick labels, etc.
    ax.set_ylabel('Latency [us]')
    #ax.set_title(title)
    if logy:
        ax.set_yscale('log')
        ax.legend(loc="lower right")
    else:
        ax.legend(loc="upper left")
        
    if logx:
        ax.set_xscale('log', base=2)

    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda y, _: sizeof_fmt(y)))
    plt.xticks(rotation=0)
    ax.set_xlabel('Message Size')
    plt.show()
    plt.savefig(f"{title}.png", format='png')

def plot_lines3(title, x_datas, y_datas, y_labels, y_styles=None, logx=True, logy=True, y_errors=None):
    if not(y_styles):
        y_styles = [None for _ in range(len(y_labels))]
    
    if not(y_errors):
        y_errors = [None for _ in range(len(y_labels))]

    fig, ax = plt.subplots(figsize=(7,6))

    for x, y, y_label, y_style, y_error in zip(x_datas, y_datas, y_labels, y_styles, y_errors):
        if y_style:
            if not y_error is None:
                ax.errorbar(x, y,  yerr = y_error, fmt=y_style, label=y_label, capsize=2.0, linewidth=1)
            else:
                ax.plot(x, y, y_style, label=y_label)
        else:
            if not y_error is None:
                ax.errorbar(x, y,  yerr = y_error, fmt=y_style, label=y_label, capsize=2.0, linewidth=1)
            else:
                ax.plot(x, y, label=y_label)
        
        if y_error is not None:
            ax.fill_between(x,y-y_error,y+y_error,alpha=.1)

    plt.grid(axis='y')
    # Add some text for labels, title and custom x-axis tick labels, etc.
    ax.set_ylabel('Latency [us]')
    #ax.set_title(title)
    if logy:
        ax.set_yscale('log')
        ax.legend(loc="lower right")
    else:
        ax.legend(loc="upper left")
        
    if logx:
        ax.set_xscale('log', base=2)

    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda y, _: sizeof_fmt(y)))
    plt.xticks(rotation=0)
    ax.set_xlabel('Message Size')
    plt.show()
    plt.savefig(f"{title}.png", format='png')

def sizeof_fmt(num, suffix='B'):
    for unit in ['','K','M','G','T','P','E','Z']:
        if abs(num) < 1024.0:
            return "%3.f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)



def compare_latency(df_exp, df_mpi, number_of_nodes=4, error=False):
    df_exp              = df_exp[ (df_exp["rank_id"] == 0) & (df_exp["number_of_nodes"]==number_of_nodes)]
    df_mpi               = df_mpi[ (df_mpi["rank_id"] == 0) & (df_mpi["number_of_nodes"]==number_of_nodes)]
    collectives     = df_exp['collective'].apply(lambda r: '_'.join(r.split('_')[:-1])).unique()
    print(collectives)
    segment_size    = 4*1024*1024
    for collective in collectives:
        subset              = df_exp[(df_exp["collective"].str.startswith(collective)) & (df_exp["segment_size[B]"] == segment_size) & (df_exp["number_of_banks"] == 4) ]
        print(subset)
        grouped             = subset.groupby(["collective", "size[B]"]).agg({'execution_time[us]':['mean','std']})
        grouped.reset_index(inplace=True)
        grouped             = grouped.groupby(["collective"])
        series_label = []
        series_y     = []
        series_x     = []
        styles       = []
        stdevs       = []
        i = 0
        for coll, group in grouped:
            print(coll)
            exe          = group['execution_time[us]']['mean'].to_numpy()
            exe_std      = group['execution_time[us]']['std'].to_numpy()
            bufsize      = group['size[B]'].to_numpy()
            
            if np.any(exe != 0):
                if "F2F" in coll:
                    series_label.append(f"HW {collective} HI")
                    series_y.append(exe)
                    series_x.append(bufsize)
                    stdevs.append(exe_std)
                    styles.append(f"C{i+1}+-")
                    i+=1
                if "K2K" in coll:
                    series_label.append(f"HW {collective} KI")
                    series_y.append(exe)
                    series_x.append(bufsize)
                    stdevs.append(exe_std)
                    styles.append(f"C{i+1}+-")
                    i+=1

        #For MPICH
        subset              = df_mpi[(df_mpi["collective"].str.startswith(collective)) ]
        print(subset)
        grouped             = subset.groupby(["collective", "size[B]"]).agg({'execution_time[us]':['mean','std']})
        grouped.reset_index(inplace=True)
        grouped             = grouped.groupby(["collective"])
        for coll, group in grouped:
            # print(group)
            exe          = group['execution_time[us]']['mean'].to_numpy()
            exe_std      = group['execution_time[us]']['std'].to_numpy()
            bufsize      = group['size[B]'].to_numpy()

            if np.any(exe != 0):
                series_label.append(f"SW {collective}")
                series_y.append(exe)
                series_x.append(bufsize)
                stdevs.append(exe_std)
                styles.append(f"C{i+1}+-")
                i+=1

        # #For OpenMPI
        # subset              = df_mpi[(df_mpi["collective name"].str.startswith(collective)) & (df_mpi["board_instance"]=="OpenMPI")]
        # grouped             = subset.groupby(["board_instance", "buffer size[KB]"]).agg({'execution_time[us]':['mean','std'], 'execution_time_fullpath[us]':['mean','std']})
        # grouped.reset_index(inplace=True)
        # grouped             = grouped.groupby(["board_instance"])
        # for board, group in grouped:
        #     exe          = group['execution_time[us]']['mean'].to_numpy()
        #     exe_std      = group['execution_time[us]']['std'].to_numpy()
        #     bufsize      = group['buffer size[KB]'].to_numpy()*1024
        #     exe_full     = group['execution_time_fullpath[us]']['mean'].to_numpy()
        #     exe_full_std = group['execution_time_fullpath[us]']['std'].to_numpy()

        #     # if np.any(exe):
        #     #     series_label.append(f"{board}")
        #     #     series_y.append(exe)
        #     #     series_x.append(bufsize)
        #     #     stdevs.append(None)
        #     #     styles.append(f"C{i}+-")
        #     if np.any(exe_full != 0):
        #         series_label.append(f"{board}_H2H")
        #         series_y.append(exe_full)
        #         series_x.append(bufsize)
        #         stdevs.append(exe_full_std)
        #         styles.append(f"C{i+1}+-")
        #         i+=1

        
        plot_lines("compare_latency_"+collective.replace("/", "")+"_nr_"+str(number_of_nodes), series_x, series_y, series_label, styles, y_label='Latency [us]', logx=True, legend_loc ="upper left", y_errors=(stdevs if error else None))




def compare_rank_with_fixed_bsize(df_exp, df_mpi, error=True):
    df_exp              = df_exp[ (df_exp["rank_id"] == 0) ]
    df_mpi               = df_mpi[ (df_mpi["rank_id"] == 0) ]
    collectives          = df_exp['collective'].apply(lambda r: '_'.join(r.split('_')[:-1])).unique()
    bsizes               = df_exp[ "size[B]"].unique()
    segment_size         = 4*1024*1024
    print(collectives)
    print(bsizes)
    for collective in collectives:
        # if collective != "sendrecv":
        if collective == "allreduce":
            print(collective)
            for bsize in bsizes:
                if bsize == 131072:
                    series_label = []
                    series_y     = []
                    series_x     = []
                    styles       = []
                    stdevs       = []
                    subset              = df_exp[(df_exp["collective"].str.startswith(collective)) &
                                            (df_exp["size[B]"] == bsize) & 
                                            (df_exp["segment_size[B]"] == segment_size) & 
                                            (df_exp["number_of_nodes"] > 3)]
                    grouped             = subset.groupby(["collective","number_of_nodes"]).agg({'execution_time[us]':['mean','std']})
                    grouped.reset_index(inplace=True)
                    print(collective, bsize, grouped)
                    grouped             = grouped.groupby(["collective"])
                    print(grouped)

                    i = 0
                    for coll, group in grouped:
                        print(coll)
                        exe          = group['execution_time[us]']['mean'].to_numpy()
                        exe_std      = group['execution_time[us]']['std'].to_numpy()
                        num_nodes    = group['number_of_nodes'].to_numpy()
                        print(num_nodes)
                        
                        if np.any(exe != 0):
                            if "F2F" in coll:
                                series_label.append(f"HW {collective} HI")
                                series_y.append(exe)
                                series_x.append(num_nodes)
                                stdevs.append(exe_std)
                                styles.append(f"C{i+1}+-")
                                i+=1
                            if "K2K" in coll:
                                series_label.append(f"HW {collective} KI")
                                series_y.append(exe)
                                series_x.append(num_nodes)
                                stdevs.append(exe_std)
                                styles.append(f"C{i+1}+-")
                                i+=1
                    
                    #OpenMPI
                    subset              = df_mpi[(df_mpi["collective"].str.startswith(collective)) & (df_mpi["size[B]"] == bsize) & (df_mpi["number_of_nodes"] > 3)]
                    print(subset)
                    grouped             = subset.groupby(["collective","number_of_nodes"]).agg({'execution_time[us]':['mean','std']})
                    grouped.reset_index(inplace=True)
                    print(collective, bsize, grouped)
                    grouped             = grouped.groupby(["collective"])
                    print(grouped)
                    for coll, group in grouped:
                        exe          = group['execution_time[us]']['mean'].to_numpy()
                        exe_std      = group['execution_time[us]']['std'].to_numpy()
                        num_nodes    = group['number_of_nodes'].to_numpy()

                        if np.any(exe != 0):
                            series_label.append(f"SW {collective}")
                            series_y.append(exe)
                            series_x.append(num_nodes)
                            stdevs.append(exe_std)
                            styles.append(f"C{i+1}+-")
                            i+=1

                    
                    plot_lines("rank_comparison_"+collective.replace("/", "")+"_"+str(bsize), series_x, series_y, series_label, styles, x_label="Number of ranks", y_label='Latency [us]', legend_loc ="upper left", logx=False, logy = False, y_errors=(stdevs if error else None))

                    #plot_clustered_bars(collective, series_x, series_y, series_label)


def remove_multiple_headers(df):
    headers = df.columns.tolist()
    df = df[df[headers[0]]!=headers[0]].reset_index(drop=True)
    for column_name in ["totalRank","localRank","pkgWordCount","payloadSize","numMsg","authenticatorLen","txBatchNum","rxBatchMaxTimer","consumed_bytes_host","produced_bytes_host","consumed_bytes_network","produced_bytes_network","consumed_pkt_network","produced_pkt_network","consumed_msg_host","produced_msg_host","execution_cycles","consumed_msg_network","produced_msg_network","device_net_down","net_device_down","host_device_down","device_host_down","net_tx_cmd_error","txNetThroughput[Gbps]","rxNetThroughput[Gbps]","txHostThroughput[Gbps]","rxHostThroughput[Gbps]","rxNetPktRate[pps]","txNetPktRate[pps]","rxHostPktRate[pps]","txHostPktRate[pps]","latency"]:
        df[column_name] = pd.to_numeric(df[column_name])
    return df

def load_csvs_under(path):

    csv_files    = [join(path, f) for f in listdir(path)  if (isfile(join(path, f)) and f.find(".csv") != -1)]
    print("csv files ingested", csv_files)
    csvs = []
    for csv_path in csv_files:
        csvs.append(pd.read_csv(csv_path))
    return pd.concat(csvs)

def load_logs_under(path):

    csv_files    = [join(path, f) for f in listdir(path)  if (isfile(join(path, f)) and f.find(".log") != -1)]
    print("csv files ingested", csv_files)
    csvs = []
    for csv_path in csv_files:
        csvs.append(pd.read_csv(csv_path))
    return pd.concat(csvs)

def compare_throughput(df_exp, eval='txNetPktRate[pps]'):

    # one to all experiment
    subset  = df_exp[(df_exp["exp"] == "one_to_all") & (df_exp["numMsg"] >= 1000)  & (df_exp["txBatchNum"] == 1) & (df_exp["rxBatchMaxTimer"] == 0) & (df_exp["pkgWordCount"] == 64) & (df_exp["authenticatorLen"] == 32) & (df_exp["totalRank"] == df_exp["localRank"] + 1) ]
    print(subset)

    series_label = []
    series_y     = []
    series_x     = []
    styles       = []
    stdevs       = []

    grouped  = subset.groupby(["payloadSize","totalRank"]).agg({eval:['mean','std']})
    grouped.reset_index(inplace=True)
    print(grouped)

    grouped  = grouped.groupby(["payloadSize"])
    print(grouped)
    j=0
    for i,(ind, group) in enumerate(grouped):
        print(group)
        txThr           = group[eval]['mean'].to_numpy()
        txThr_std       = group[eval]['std'].to_numpy()
        rank            = group['totalRank'].to_numpy()

        print(txThr)
        print(rank)

        if np.any(txThr != 0):
            series_label.append(f"Payload[B]:{ind}")
            series_y.append(txThr)
            series_x.append(rank)
            stdevs.append(txThr_std)
            styles.append(f"C{j+1}-+")
            j+=1

    plot_lines(f"{eval}_vs_rank_one_to_all", series_x, series_y, series_label, styles, x_label="Rank", y_label=eval, legend_loc ="upper left", logx=False, logy=False)


    # all to all experiment
    subset  = df_exp[(df_exp["exp"] == "all_to_all") & (df_exp["numMsg"] == 2000)  & (df_exp["txBatchNum"] == 1) & (df_exp["rxBatchMaxTimer"] > 0) & (df_exp["pkgWordCount"] == 64) & (df_exp["authenticatorLen"] == 32) ]
    print(subset)

    series_label = []
    series_y     = []
    series_x     = []
    styles       = []
    stdevs       = []

    grouped  = subset.groupby(["payloadSize","totalRank"]).agg({eval:['mean','std']})
    grouped.reset_index(inplace=True)
    print(grouped)

    grouped  = grouped.groupby(["payloadSize"])
    print(grouped)
    j=0
    for i,(ind, group) in enumerate(grouped):
        print(group)
        txThr           = group[eval]['mean'].to_numpy()
        txThr_std       = group[eval]['std'].to_numpy()
        rank            = group['totalRank'].to_numpy()

        print(txThr)
        print(rank)

        if np.any(txThr != 0):
            series_label.append(f"Payload[B]:{ind}")
            series_y.append(txThr)
            series_x.append(rank)
            stdevs.append(txThr_std)
            styles.append(f"C{j+1}-+")
            j+=1

    plot_lines(f"{eval}_vs_rank_all_to_all", series_x, series_y, series_label, styles, x_label="Rank", y_label=eval, legend_loc ="upper left", logx=False, logy=False)





if __name__ == "__main__":
    log_path            ="./"
    df_exp = load_logs_under(log_path)
    df_exp = remove_multiple_headers(df_exp)
    print(df_exp)

    import argparse

    parser = argparse.ArgumentParser(description='Creates some graphs.')
    parser.add_argument('--rank'                , action='store_true', default=False,    help='compare performance of different number of ranks'   )
    parser.add_argument('--throughput'          , action='store_true', default=False,     help='compare throughput'   )
    parser.add_argument('--latency'             , action='store_true', default=False,     help='compare latency'   )


    args = parser.parse_args()
    if args.throughput:
        for eval in ["txNetThroughput[Gbps]","txNetPktRate[pps]","produced_bytes_network","device_net_down","net_device_down","host_device_down","device_host_down","net_tx_cmd_error"]:
            compare_throughput(df_exp, eval)
