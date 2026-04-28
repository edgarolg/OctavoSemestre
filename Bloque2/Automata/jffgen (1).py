import html


def build_sets():
    letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    digits = "0123456789"
    word = letters + digits + "_"
    blank = " \t\n"
    arithmetic = "+-*/"
    logic = "<=>!"
    parentheses = "(){}[]"
    other = ''';,"'''
    alphabet = letters + digits + arithmetic + logic + parentheses + other

    return {
        "1": letters,
        "2": digits,
        "3": word,
        "4": blank,
        "5": arithmetic,
        "6": logic,
        "7": parentheses,
        "8": other,
        "9": alphabet,
    }


def parse_selection(selection, sets_dict):
    """
    Parses input like:
    '23\\+_?.,'
    -> sets 2 and 3 + literal chars '+_?.,'
    """
    if "\\" in selection:
        set_part, literal_part = selection.split("\\", 1)
    else:
        set_part, literal_part = selection, ""

    chars = set()

    # Add sets
    for key in set_part:
        if key in sets_dict:
            chars.update(sets_dict[key])
        else:
            print(f"Warning: set {key} not defined")

    # Add literal characters
    chars.update(literal_part)

    return chars


def main():
    sets_dict = build_sets()

    from_states = input("From states (comma-separated): ").split(',')
    to_states = input("To states (comma-separated): ").split(',')

    print("Available sets:")
    for k, v in sets_dict.items():
        print(f"{k}: {repr(v)}")

    selection = input(
        "Select sets (e.g. 23 or 23\\+_?.,): "
    )

    chosen_chars = parse_selection(selection, sets_dict)

    exceptions = input("Exceptions (chars, no commas needed): ")
    chosen_chars = [c for c in chosen_chars if c not in exceptions]

    with open("transitions.jff", "w") as f:
        for from_state in from_states:
            for to_state in to_states:
                for char in chosen_chars:
                    simbol = html.escape(char)
                    transition = (
                        "<transition>\n"
                        f"\t<from>{from_state.strip()}</from>\n"
                        f"\t<to>{to_state.strip()}</to>\n"
                        f"\t<read>{simbol}</read>\n"
                        "</transition>\n"
                    )
                    f.write(transition)

    print("Transitions generated successfully.")


if __name__ == "__main__":
    main()
