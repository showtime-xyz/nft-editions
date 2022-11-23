#!/usr/bin/env python3


# for compound tests like mint1000, we need to adjust for n * intrinsic gas
collections_to_adjust = ["solmateErc721", "edition"]

INTRINSIC_GAS = 21000


def main():
    gas_snapshot = open(".gas-snapshot").readlines()

    tests = set()
    results = dict()
    for line in gas_snapshot:
        if "GasBench" not in line:
            continue

        # ['GasBench:test', 'solmateErc721', 'ownerOf() (gas: 8036)']
        tokens = line.split("__")
        collection = tokens[1]
        if collection not in results:
            results[collection] = dict()

        # ['ownerOf', ') ', 'gas: 8036)']
        test = tokens[2].split("(")[0]
        tests.add(test)

        # ['ownerOf() (gas', '8036)']
        gas_tok = tokens[2].split(": ")
        gas = int(gas_tok[1].strip().replace(")", ""))

        if collection in collections_to_adjust and test.startswith("mint"):
            n = int(test.split("mint")[1])
            gas += (n - 1) * INTRINSIC_GAS
            print("adjusted gas for", collection, test, "to", gas)

        results[collection][test] = gas

    print("collection\t" + "\t".join(sorted(tests)))

    for collection in sorted(results.keys()):
        print(collection, end="\t")
        for test in sorted(tests):
            if test in results[collection]:
                print(results[collection][test], end="\t")
            else:
                print("-", end="\t")
        print()


if __name__ == "__main__":
    main()
