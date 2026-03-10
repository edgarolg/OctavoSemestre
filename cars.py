from matplotlib import pyplot as plt
import numpy as numpy
import seaborn as sb
import pandas as pd
import csv
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score

import pandas as pd
cars = pd.read_csv('filename.csv')
cars.head()

cars.info
cars.shape
cars.describe()

cars[cars['Used/New'] != 'Used'].tail()
cars[cars["SellerType"] != "Dealer"].head()
cars[['Make','Model']].head()
dummies_make = pd.get_dummies(cars['Make'], prefix='make', dtype=int)
dummies_make.head()
data = cars[["Used/New", "Price", "ConsumerRating", "ConsumerReviews", "SellerType", "SellerRating", "InteriorColor", "Drivetrain", "MinMPG", "MaxMPG", "FuelType", "Transmission", "Engine", "Mileage"]]
data.loc[data["Price"].str.contains('Not Priced', case=False, na=False), "Price"] = '0'
data.head(60).tail()
data['Price'] = data['Price'].str.replace('$', '', regex=False).str.replace(',', '', regex=False).astype(int)

data["Used/New"] = data['Used/New'].str.replace('Used', '0', regex=False)
data.loc[data["Used/New"].str.contains('certified', case=False, na=False), "Used/New"] = '1'
data["Used/New"] = data['Used/New'].astype(int)

X = data.drop(columns=['Used/New'])
y = pd.Series(data['Used/New'], name='target')

Xdum = pd.get_dummies(X, dtype=int)
Xdum.info()
Xdum.head()
X_train, X_test, y_train, y_test = train_test_split(Xdum, y, test_size=0.2, random_state=42)

#Scalar
scaler = StandardScaler()
x_train_scaled = scaler.fit_transform(X_train)
x_test_scaled = scaler.transform(X_test)

model = LogisticRegression(max_iter=10000)
model.fit(x_train_scaled, y_train)

y_pred = model.predict(x_test_scaled)
accuracy = accuracy_score(y_test, y_pred)
print(f"Model Accuracy: {accuracy:.2f}")

