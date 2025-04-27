defmodule Vik.Dates do
  @moduledoc false

  @minute 60
  @hour @minute * 60
  @day @hour * 24
  @month @day * 30
  @year @month * 12

  def humanize(%Date{} = date) do
    s = Date.diff(Date.utc_today(), date)

    cond do
      s <= 0 -> "today"
      s <= 1 -> "yesterday"
      s <= 2 -> "a minute ago"
      Integer.mod(s, 7) == 0 and div(s, 7) == 1 -> "a week ago"
      Integer.mod(s, 7) == 0 -> "#{div(s, 7)} weeks ago"
      s == 1 -> "a day ago"
      true -> "#{s} days ago"
    end
  end

  def humanize(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> humanize()
  end

  def humanize(%DateTime{} = datetime) do
    s = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      s <= 0 -> "now"
      s <= 45 -> "a few seconds ago"
      s <= @minute -> "a minute ago"
      s <= 45 * @minute and div(s, @minute) == 1 -> "a minute ago"
      s <= 45 * @minute -> "#{div(s, @minute)} minutes ago"
      s <= 1.5 * @hour -> "an hour ago"
      s <= 22 * @hour and div(s, @hour) == 1 -> "an hour ago"
      s <= 22 * @hour -> "#{div(s, @hour)} hours ago"
      s <= 1.5 * @day -> "a day ago"
      s <= 25 * @day and div(s, @day) == 1 -> "a day ago"
      s <= 25 * @day -> "#{div(s, @day)} days ago"
      s <= 1.5 * @month -> "a month ago"
      s <= 11.5 * @month and div(s, @month) == 1 -> "a month ago"
      s <= 11.5 * @month -> "#{div(s, @month)} months ago"
      s <= 1.5 * @year -> "a year ago"
      div(s, @year) == 1 -> "a year ago"
      true -> "#{div(s, @year)} years ago"
    end
  end
end
