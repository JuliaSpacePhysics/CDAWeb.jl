# Agent eval

Measures what CDAWeb.jl saves an agent on common research tasks (find a dataset, fetch it, reduce it to a number), against an agent free to use anything else (`cdasws`, `pyspedas`, HAPI, `curl`, ...). Accuracy saturates for strong models, so the measures that matter are turns, context tokens and cost.

```sh
python3 eval/run.py                                   # every task, both arms, sonnet
python3 eval/run.py --models sonnet opus -n 3 --tasks psp-bmax
```

- `tasks.toml`: prompts and answers. Prompts name what a researcher would (mission, instrument, quantity), not dataset ids.
- The `cdaweb` arm gets `eval/Project.toml` and the path of the package README, its only documentation.
- Caches stay warm across runs (`~/.cdaweb`, `SPEDAS_DATA_DIR`), as in real use; the first run of a task downloads its data.
- `results/<time>/`: `results.jsonl` and per-run stream-json transcripts; `eval/trace.py <transcript>` shows where the turns went.
