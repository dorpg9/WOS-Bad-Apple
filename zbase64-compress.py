import argparse
import zstandard as zstd
import base64
import sys

# courtesy of chatgpt

def compress_and_base64_encode(data: bytes) -> str:
    compressor = zstd.ZstdCompressor()
    compressed = compressor.compress(data)
    b64_encoded = base64.b64encode(compressed)
    return b64_encoded.decode('utf-8')

def main():
    parser = argparse.ArgumentParser(description="Compress a file with Zstandard and output Base64 encoded data.")
    parser.add_argument('input', help="Input file path. Use '-' for stdin.")
    parser.add_argument('-o', '--output', help="Output file path. Defaults to stdout.", default=None)

    args = parser.parse_args()

    # Read input
    if args.input == '-':
        binary_data = sys.stdin.buffer.read()
    else:
        with open(args.input, 'rb') as f:
            binary_data = f.read()

    # Compress and encode
    result = compress_and_base64_encode(binary_data)

    # Write output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(f'{{\"m\":null,\"t\":\"buffer\",\"zbase64\":\"{result}\"}}')
    else:
        print(result)

if __name__ == "__main__":
    main()