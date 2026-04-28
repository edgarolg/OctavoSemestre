import re
import html


def extract_data(file_location):
    with open(file_location, 'r') as file:
        xml_data = file.read()
    transition_data = "\n".join(re.findall(
        r'<transition>.*?</transition>', xml_data, re.DOTALL)).replace('\t', '')
    state_data = "\n".join(re.findall(
        r'<state id="\d+".*?</state>', xml_data, re.DOTALL)).replace('\t', '')
    return state_data, transition_data


def parse_states(state_data):
    states = []
    initial_state = None
    final_states = []
    states_label = {}

    state_pattern = re.compile(r'<state id="\d+".*?</state>', re.DOTALL)
    matches = state_pattern.findall(state_data)
    for match in matches:
        state_id = int(re.search(r'<state id="(\d+)"', match).group(1))
        is_initial = bool(re.search(r'<initial/>', match))
        is_final = bool(re.search(r'<final/>', match))
        label = re.search(r'<label>(\d+)</label>', match)
        if label:
            label = label.group(1)

        states.append(state_id)
        states_label[state_id] = label

        if is_initial:
            initial_state = state_id

        if is_final:
            final_states.append(state_id)

    return states, initial_state, final_states, states_label


def parse_transitions(transition_data):
    transitions = []
    transition_pattern = re.compile(r'<transition>.*?</transition>', re.DOTALL)
    matches = transition_pattern.findall(transition_data)
    for match in matches:
        from_state = re.search(r'<from>(\d+)</from>', match).group(1)
        to_state = re.search(r'<to>(\d+)</to>', match).group(1)
        read_char = re.search(r'<read>(.*?)</read>', match).group(1)

        transitions.append((from_state, to_state, read_char))

    return transitions


state_data, transition_data = extract_data('./FullAutomaton.jff')

states, initial_state, final_states, states_label = parse_states(state_data)
transitions = parse_transitions(transition_data)

# Build the alphabet and transition matrix dynamically
alphabet = []
alphabet_index = {}
transitions_dict = {}
max_state_id = max(states)

# Initialize the transition matrix with -1 (indicating no transition)
transition_matrix = [[-1] * len(alphabet) for _ in range(max_state_id + 1)]

for from_state, to_state, read_char in transitions:
    from_state = int(from_state)
    to_state = int(to_state)

    # Unparse the read_char if it is parsed in the XML
    read_char = html.unescape(read_char)

    if read_char not in alphabet_index:
        alphabet_index[read_char] = len(alphabet)
        alphabet.append(read_char)
        # Extend all rows in the transition matrix for the new character
        for row in transition_matrix:
            row.append(-1)

    # Ensure the from_state has an entry in the transitions_dict
    if from_state not in transitions_dict:
        transitions_dict[from_state] = [-1] * len(alphabet)

    # Update the transitions_dict and transition_matrix
    if len(transitions_dict[from_state]) < len(alphabet):
        transitions_dict[from_state].extend(
            [-1] * (len(alphabet) - len(transitions_dict[from_state])))

    transitions_dict[from_state][alphabet_index[read_char]] = to_state
    transition_matrix[from_state][alphabet_index[read_char]] = to_state

with open('./Full_transition_table_in_C.txt', 'w') as file:

    # --- dimensions ---
    file.write(f"#include <stdio.h>\n\n")

    file.write(f"#define STATE_COUNT {len(states)}\n")
    file.write(f"#define ALPHABET_SIZE {len(alphabet)}\n\n")

    # --- transition matrix ---
    file.write("int mt[STATE_COUNT][ALPHABET_SIZE] = {\n")

    for i, row in enumerate(transition_matrix):
        file.write("    {")
        for j, element in enumerate(row):
            file.write(f"{element}")
            if j < len(row) - 1:
                file.write(", ")
        file.write("}")
        if i < len(transition_matrix) - 1:
            file.write(",\n")
        else:
            file.write("\n")

    file.write("};\n\n")

    # --- alphabet ---
    file.write("char alphabet[ALPHABET_SIZE] = {")
    for i, char in enumerate(alphabet):
        # escape quotes if needed
        if char == "'":
            file.write("'\\''")
        elif char == '"':
            file.write("'\"'")
        else:
            file.write(f"'{char}'")

        if i < len(alphabet) - 1:
            file.write(", ")
    file.write("};\n\n")

    # --- states ---
    file.write("int states[STATE_COUNT] = {")
    for i, state in enumerate(states):
        file.write(f"{state}")
        if i < len(states) - 1:
            file.write(", ")
    file.write("};\n\n")

    # --- initial state ---
    file.write(f"int initialState = {initial_state};\n\n")

    # --- final states ---
    file.write("int finals[] = {")
    for i, final_state in enumerate(final_states):
        file.write(f"{final_state}")
        if i < len(final_states) - 1:
            file.write(", ")
    file.write("};\n\n")

    # --- state labels ---
    file.write("int states_code[STATE_COUNT] = {")
    for i, state in enumerate(states):
        label = states_label.get(state)
        if label is None:
            label = -1
        file.write(f"{label}")
        if i < len(states) - 1:
            file.write(", ")
    file.write("};\n")

print("C conversion completed successfully!")
