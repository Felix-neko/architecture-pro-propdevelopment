import pandas as pd


if __name__ == "__main__":
    df = pd.read_json(open("audit_5.log"), lines=True)
    # Тут ставим Breakpoint, чтобы можно было открывать датафрейм в PyCharm как View As Dataframe --
    # -- и смотреть как в Excel, с поиском и фильтрацией
    print(df)
