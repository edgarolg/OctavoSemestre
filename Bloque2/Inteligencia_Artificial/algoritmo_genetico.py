import numpy as np
import math

# --- Configuración ---
N = 20  # Tamaño de la población
L = 10  # Longitud del cromosoma (bits)
IN = 0  # Índice para fitness individual
CU = 1  # Índice para fitness acumulado (para selección)

# Inicialización de estructuras
population = np.zeros((N, L), dtype=int)
newpop = np.zeros((N, L), dtype=int)
fitness = np.zeros((N, 2)) # [0] = fitness, [1] = acumulado

def initial():
    """Genera una población aleatoria de bits."""
    global population
    population = np.random.randint(2, size=(N, L))

def evaluation():
    """Calcula el valor decimal de los bits y evalúa la función fitness."""
    global fitness
    for ind in range(N):
        # Convertir bits a decimal
        dec = 0
        for gen in range(L):
            dec = (population[ind][gen] * (2**(L - 1 - gen))) + dec
        
        # Escalar con precisión de 4 dígitos (según tu código de C)
        decimal = dec / 10000.0
        
        # Evitar división por cero si decimal es 0
        if decimal == 0:
            fitness[ind][IN] = 0 
        else:
            # f(x) = sin(4 * x^3) / x
            fitness[ind][IN] = math.sin(4 * pow(decimal, 3)) / decimal

def selection():
    """Selección por ruleta (basado en fitness acumulado)."""
    global newpop
    # Guardar el mejor (Elitismo simplificado según tu lógica)
    best_idx = np.argmax(fitness[:, IN])
    newpop[0] = population[best_idx]
    
    # En Python, el cálculo de acumulados es más fácil con cumsum
    total_fitness = np.sum(fitness[:, IN])
    if total_fitness == 0:
        probs = np.ones(N) / N
    else:
        probs = fitness[:, IN] / total_fitness
    
    cumulative_probs = np.cumsum(probs)
    
    for ind in range(1, N):
        probab = np.random.random() # Valor entre 0 y 1
        # Buscar qué individuo le corresponde la suerte
        for parent in range(N):
            if probab <= cumulative_probs[parent]:
                newpop[ind] = population[parent]
                break

def reproduction():
    """Crossover (Cruza) de un solo punto."""
    global population
    for ind in range(0, N - 1, 2):
        pcross = np.random.randint(1, L)
        # Hijo 1: Parte de padre 1 + parte de padre 2
        population[ind][:pcross] = newpop[ind][:pcross]
        population[ind][pcross:] = newpop[ind+1][pcross:]
        
        # Hijo 2: Parte de padre 2 + parte de padre 1
        population[ind+1][:pcross] = newpop[ind+1][:pcross]
        population[ind+1][pcross:] = newpop[ind][pcross:]

def mutation():
    """Agregado: Usualmente necesaria en algoritmos genéticos."""
    for ind in range(N):
        if np.random.random() < 0.01: # 1% de probabilidad
            p = np.random.randint(0, L)
            population[ind][p] = 1 - population[ind][p]

def convergence():
    """Criterio de parada (puedes ajustarlo por generaciones)."""
    # Aquí puedes definir si ya encontraste un valor óptimo o 
    # simplemente contar 100 iteraciones.
    return True 

# --- Ciclo Principal ---
initial()
generaciones = 0
max_gen = 100

while generaciones < max_gen:
    evaluation()
    selection()
    reproduction()
    mutation()
    
    # Mostrar el mejor de esta generación
    best_val = np.max(fitness[:, IN])
    print(f"Gen {generaciones}: Mejor Fitness = {best_val}")
    
    generaciones += 1