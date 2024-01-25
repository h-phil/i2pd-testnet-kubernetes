import sys
import ipaddress
from scapy.all import PcapReader
from scapy.layers.inet import IP
import networkx as nx
import matplotlib.pyplot as plt
import seaborn as sns

net = ipaddress.IPv4Network("10.8.0.0/16")

def create_topology_graph(pcap_file):
    # Read pcap file (generator)
    packets = PcapReader(pcap_file)

    # Initialize a directed graph
    graph = nx.DiGraph()

    # Initialize a dictionary to store the amount of traffic between each pair of nodes
    traffic = {}

    # Iterate through packets to build the graph and calculate traffic
    for packet in packets:
        if IP in packet:
            src_ip = packet[IP].src
            dst_ip = packet[IP].dst

            sip = ipaddress.IPv4Address(src_ip)
            dip = ipaddress.IPv4Address(dst_ip)

            if sip not in net or dip not in net:
                continue

            # Update nodes and edges
            graph.add_node(src_ip)
            graph.add_node(dst_ip)
            graph.add_edge(src_ip, dst_ip)

            # Update traffic information
            key = (src_ip, dst_ip)
            rev_key = (dst_ip, src_ip)
            if key in traffic:
                traffic[key] += len(packet)
            elif rev_key in traffic:
                traffic[rev_key] += len(packet)
            else:
                traffic[key] = len(packet)

    return graph, traffic

def get_closest(traffic):
    unordered_traffic_list = []
    for k, v in traffic.items():
        unordered_traffic_list.append((k,v))

    sorted_list = sorted(unordered_traffic_list, key=lambda x: x[1])

    for e in sorted_list:
        print(e)

def visualize_topology(graph, traffic, output_file):
    # Calculate edge thickness based on traffic

    max_t = max(traffic.values())

    edge_thickness = []
    edge_labels = {}

    for src, dst in graph.edges():
        k = (src, dst)
        rk = (dst, src)
        if k in traffic:
            t = traffic[k]
            edge_labels[k] = t
            edge_thickness.append(t / max_t)
        elif rk in traffic:
            t = traffic[rk]
            edge_labels[rk] = t
            edge_thickness.append(t / max_t)
        else:
            raise Exception(f"missing traffic for {src}-{dst}")

    # Draw the graph with varying edge thickness
    pos = nx.spring_layout(graph)

    # Use seaborn color palette for a more visually appealing graph
    node_colors = sns.color_palette("Set2", n_colors=len(graph.nodes()))

    # Draw the graph with additional styling
    nx.draw(graph, pos, with_labels=True, font_weight='bold', node_size=700, node_color=node_colors, font_size=8, edge_color="black", width=edge_thickness, arrows=False)

    # Add edge labels to the graph
    nx.draw_networkx_edge_labels(graph, pos, edge_labels=edge_labels, font_size=6)

    # Save the graph as a PNG file
    plt.savefig(output_file, format="png", dpi=600)
    plt.show()
    plt.close()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <pcap_file> <output_file.png>")
        sys.exit(1)

    pcap_file = sys.argv[1]
    output_file = sys.argv[2]

    topology_graph, traffic_info = create_topology_graph(pcap_file)
    get_closest(traffic_info)
    visualize_topology(topology_graph, traffic_info, output_file)

    print(f"Network topology graph saved as {output_file}")

