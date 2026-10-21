import argparse
from pathlib import Path
from Tools.collect_integration_captures import stage

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Stage unmodified native capture evidence without large xcresults")
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--attachments", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--family", required=True)
    parser.add_argument("--run", type=int, required=True)
    args = parser.parse_args()
    print("Staged native files:", stage(args.summary, args.attachments, args.output, args.source, args.family, args.run))
