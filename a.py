X = [[0, 0], [0, 1], [1, 0], [1, 1]]
y = [0, 0, 0, 1]


w1 = 0.0
w2 = 0.0
bias = 0.0


k = 0.05
epochs = 10


def activacion(z):
    if z >= 0:
        return 1
    else:
        return 0


for epoch in range(epochs):


    for i in range(len(X)):
        z = w1 * X[i][0] + w2 * X[i][1] + bias
        y_pred = activacion(z)


        error = y[i] - y_pred


        w1 += k * error * X[i][0]
        w2 += k * error * X[i][1]
        bias += k * error


    print("\nEpoca", epoch + 1)
    print("w1 =", round(w1, 3), "w2 =", round(w2, 3), "bias =", round(bias, 3))
    correcto = True


    for i in range(len(X)):
        z = w1 * X[i][0] + w2 * X[i][1] + bias
        y_pred = activacion(z)


        if y_pred == y[i]:
            print("Entrada", X[i], y_pred, "Correcto")
        else:
            print("Entrada", X[i], y_pred, "Incorrecto")
            correcto = False


print("\nPesos finales:")
print("w1 =", w1, "w2 =", w2, "bias =", bias)

