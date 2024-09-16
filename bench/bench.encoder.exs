bench_options = [
  time: 5,
  memory_time: 2,
  inputs: %{
    "simple document" => :simple,
    "deeply nested elements " => :nested,
    "long content element" => :long_content
  }
]

defmodule Bench.Sassone.Builder do
  import Sassone.XML, only: [element: 3]

  def build(:simple) do
    element(nil, "root", [], [
      element(nil, "element1", [], []),
      element(
        nil,
        "element2",
        [],
        Enum.map(0..9, fn index ->
          element(nil, "element2.#{index}", [], "foo")
        end)
      ),
      element(nil, "element3", [], [])
    ])
  end

  def build(:nested) do
    Enum.reduce(1000..1, "content", fn index, acc ->
      element(nil, "element.#{index}", [], acc)
    end)
  end

  # Make them available in compile time.
  @strings for _ <- 0..999, do: "Jag Älskar Sverige"
  @long_string String.duplicate("Jag Älskar Sverige", 1000)

  def build(:long_content) do
    element(
      nil,
      "root",
      [],
      [
        element(nil, "many-strings", [], @strings),
        element(nil, "long-string", [], @long_string)
      ]
    )
  end
end

defmodule Bench.XMLBuilder.Builder do
  import XmlBuilder, only: [document: 3, element: 3]

  def build(:simple) do
    document("root", [], [
      element(nil, "element1", [], []),
      element(
        nil,
        "element2",
        [],
        Enum.map(0..9, fn index ->
          element(nil, "element2.#{index}", [], "foo")
        end)
      ),
      element(nil, "element3", [], [])
    ])
  end

  def build(:nested) do
    document(
      "level1",
      [],
      Enum.reduce(1000..2, "content", fn index, acc ->
        [element(nil, "element.#{index}", [], acc)]
      end)
    )
  end

  # Make it available in compile time.
  @strings for _ <- 0..999, do: "Jag Älskar Sverige"
  @long_string String.duplicate("Jag Älskar Sverige", 1000)

  def build(:long_content) do
    document(
      "root",
      [],
      [
        element(nil, "many-strings", [], @strings),
        element(nil, "long-string", [], @long_string)
      ]
    )
  end
end

Benchee.run(
  %{
    "Sassone (red apple)" => fn sample ->
      sample
      |> Bench.Sassone.Builder.build()
      |> Sassone.encode!()
    end,
    "XML Builder without formatting (red apple)" => fn sample ->
      sample
      |> Bench.XMLBuilder.Builder.build()
      |> XmlBuilder.generate(format: :none)
    end,
    "XML Builder with formatting (green apple)" => fn sample ->
      sample
      |> Bench.XMLBuilder.Builder.build()
      |> XmlBuilder.generate()
    end
  },
  bench_options
)
