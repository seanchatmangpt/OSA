# GGEN: SPARQL Correlator for Fortune 5

**Purpose:** Fortune 5 Layer 4: Correlation - SPARQL queries for SPR generation

## Directory Structure

```
ggen/
├── README.md          # This file
└── sparql/
    ├── construct_modules.rq    # Generate modules.json from workspace.ttl
    ├── construct_deps.rq        # Generate deps.json from workspace.ttl
    └── construct_patterns.rq    # Generate patterns.json from workspace.ttl
```

## Usage

```bash
# Using Apache Jena ARQ
arq --data=priv/sensors/workspace.ttl --query=ggen/sparql/construct_modules.rq

# Using RDF.rb
sparql-query --execute ggen/sparql/construct_modules.rq priv/sensors/workspace.ttl

# Using Python rdflib
python3 -c "
from rdflib import Graph
g = Graph()
g.parse('priv/sensors/workspace.ttl', format='turtle')
results = g.query(open('ggen/sparql/construct_modules.rq').read())
print(results.serialize(format='json'))
"
```

## Signal Theory Encoding

All queries follow: S=(code,spec,inform,sparql,query)

## Fortune 5 Layer Mapping

- **Layer 3 (Data Recording):** workspace.ttl (RDF/Turtle)
- **Layer 4 (Correlation):** SPARQL CONSTRUCT queries (this directory)
- **Output:** SPR JSON files (modules.json, deps.json, patterns.json)
