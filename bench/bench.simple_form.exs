inputs =
  Map.new(Path.wildcard("samples/*.*"), fn sample ->
    binary = sample |> Path.expand() |> File.read!()
    {sample, {binary, String.to_charlist(binary)}}
  end)

bench_options = [
  time: 10,
  memory_time: 2,
  inputs: inputs
]

sassone_parser = fn {data, _} ->
  {:ok, _} = Sassone.SimpleForm.parse_string(data)
end

erlsom_parser = fn {_, data} ->
  {:ok, _, _} = :erlsom.simple_form(data)
end

exomler_parser = fn {data, _} ->
  {_, _, _} = :exomler.decode(data)
end

Benchee.run(
  %{
    "Sassone (green apple)" => sassone_parser,
    "Erlsom (green apple)" => erlsom_parser,
    "Exomler (red apple)" => exomler_parser
  },
  bench_options
)
