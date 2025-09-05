import pandas as pd


if __name__ == "__main__":
    df = pd.read_json(open("audit_5.log"), lines=True)
    print(df)
