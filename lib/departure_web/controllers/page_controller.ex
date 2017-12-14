defmodule DepartureWeb.PageController do
  use DepartureWeb, :controller

  def get_data do
    case HTTPoison.get 'http://developer.mbta.com/lib/gtrtfs/Departures.csv' do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> 
        body
        |> decode_csv
        |> format_data
      {:ok, %HTTPoison.Response{status_code: 404}} -> IO.puts "Not found."
      {:error, %HTTPoison.Error{reason: reason}} -> IO.inspect reason
    end
  end

  def decode_csv(csv) do
    alias NimbleCSV.RFC4180, as: CSV
    CSV.parse_string csv
  end

  def format_data(data) do
    for [h|row] <- data do
      for {col, i} <- Enum.with_index(row) do
        {_, new_col} = 
          case Integer.parse col do
            :error    -> {:error, col}
            {time, _} -> 
              case time > 1000000 do
                false -> {:error, col}
                true  -> 
                  time 
                  |> DateTime.from_unix! 
                  |> Timex.Timezone.convert(Timex.Timezone.local) 
                  |> Timex.format("%l:%M %p", :strftime)
              end
          end

        col = cond do
          col !== new_col -> new_col
          i === 4 && col === "0" -> ""
          i === 4 -> 
            case Integer.parse col do
              :error    -> col
              {time, _} -> "#{Float.to_string(time / 60)} min"
            end
          i === 5 && col === "" -> "TBD"
          true -> col
        end
      end
    end
  end

  def index(conn, _params) do
    data = get_data
    {:ok, date_str} = Timex.format(Timex.local, "%A %m-%d-%Y", :strftime)
    {:ok, time_str} = Timex.format(Timex.local, "Current Time:\n%l:%M %p", :strftime)

    conn
    |> assign(:date, date_str)
    |> assign(:time, time_str)
    |> assign(:data, data)
    |> render("index.html")
  end
end
