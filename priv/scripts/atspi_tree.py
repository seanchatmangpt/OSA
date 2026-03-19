#!/usr/bin/env python3
"""
Extract the accessibility tree via AT-SPI2 and output as JSON.

Usage: python3 atspi_tree.py [--max-depth N] [--max-elements N]

Returns a JSON array of interactive elements:
  [{"role": "push button", "name": "Save", "x": 500, "y": 300, "width": 80, "height": 30}, ...]

Requires: python3-gi, gir1.2-atspi-2.0 (usually pre-installed on GNOME/GTK desktops)
"""

import json
import sys

import gi
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi

# Roles we consider interactive (worth showing to the LLM)
INTERACTIVE_ROLES = {
    'push button', 'toggle button', 'radio button', 'check box',
    'text', 'password text', 'entry', 'search bar',
    'link', 'menu item', 'menu', 'tab', 'page tab',
    'combo box', 'slider', 'spin button', 'scroll bar',
    'tool bar', 'tree item', 'list item',
}

# Roles we always skip (noise)
SKIP_ROLES = {
    'redundant object', 'filler', 'separator', 'unknown',
    'section', 'block quote', 'form', 'grouping',
}


def walk(obj, depth=0, max_depth=5, max_elements=200):
    """Recursively walk the accessibility tree."""
    if depth > max_depth or obj is None:
        return []

    elements = []
    try:
        role = obj.get_role_name()
        name = (obj.get_name() or '').strip()

        if role in SKIP_ROLES:
            pass  # still walk children
        else:
            comp = obj.get_component_iface()
            if comp:
                rect = comp.get_extents(Atspi.CoordType.SCREEN)
                x, y, w, h = rect.x, rect.y, rect.width, rect.height
            else:
                x = y = w = h = 0

            # Filter: reject INT_MIN sentinel values (offscreen/unmapped)
            valid_coords = (x > -100000 and y > -100000)
            has_size = (w > 0 and h > 0)

            # Include if: interactive role with valid coords, OR has name + size
            if valid_coords and (
                (role in INTERACTIVE_ROLES and has_size) or
                (name and has_size and role not in ('application', 'panel', 'desktop frame'))
            ):
                elements.append({
                    'role': normalize_role(role),
                    'name': name,
                    'x': x, 'y': y,
                    'width': w, 'height': h,
                })

        # Walk children
        n = obj.get_child_count()
        for i in range(min(n, 100)):  # cap children per node
            if len(elements) >= max_elements:
                break
            child = obj.get_child_at_index(i)
            elements.extend(walk(child, depth + 1, max_depth, max_elements - len(elements)))

    except Exception:
        pass

    return elements


def normalize_role(role):
    """Map AT-SPI role names to our canonical short names."""
    mapping = {
        'push button': 'button',
        'toggle button': 'toggle',
        'radio button': 'radio',
        'check box': 'checkbox',
        'text': 'textfield',
        'password text': 'textfield',
        'entry': 'textfield',
        'search bar': 'searchfield',
        'page tab': 'tab',
        'menu item': 'menuitem',
        'combo box': 'combobox',
        'spin button': 'slider',
        'scroll bar': 'scrollbar',
        'tool bar': 'toolbar',
        'tree item': 'menuitem',
        'list item': 'menuitem',
    }
    return mapping.get(role, role)


def main():
    max_depth = 5
    max_elements = 200

    # Parse args
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg == '--max-depth' and i + 1 < len(args):
            max_depth = int(args[i + 1])
        elif arg == '--max-elements' and i + 1 < len(args):
            max_elements = int(args[i + 1])

    desktop = Atspi.get_desktop(0)
    all_elements = []

    for i in range(desktop.get_child_count()):
        if len(all_elements) >= max_elements:
            break
        app = desktop.get_child_at_index(i)
        all_elements.extend(walk(app, max_depth=max_depth, max_elements=max_elements - len(all_elements)))

    json.dump(all_elements, sys.stdout, ensure_ascii=False)


if __name__ == '__main__':
    main()
