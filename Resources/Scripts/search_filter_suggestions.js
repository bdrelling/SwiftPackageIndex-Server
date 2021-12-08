// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

export class SPISearchFilterSuggestions {
  static suggestions = [
    {
      text: 'number of stars',
      filter: 'stars:>500',
      description: 'Filter to packages having more than 500 stars.',
    },
    {
      text: 'last maintenance activity',
      filter: `last_activity:>${this.formattedFilterDate()}`,
      description: 'Filter to packages having a commit or a closed/merged pull request or issue in the last 30 days.',
    },
    {
      text: 'last commit',
      filter: `last_commit:>${this.formattedFilterDate()}`,
      description: 'Filter to packages having a commit in the last 30 days.',
    },
  ]

  constructor() {
    document.addEventListener('turbo:before-cache', () => {
      // Remove any search filter suggestions before the page is cached so they can be
      // re-inserted correctly. Otherwise, the handler events all get removed.
      const suggestionElements = document.querySelectorAll('.filter_suggestions .suggestion')
      suggestionElements.forEach((suggestionElement) => {
        suggestionElement.remove()
      })
    })

    document.addEventListener('turbo:load', () => {
      const filterSuggestionsElement = document.querySelector('.filter_suggestions')
      if (!filterSuggestionsElement) return
      const searchFieldElement = document.querySelector('form input[type=search]')
      if (!searchFieldElement) return

      const suggestionElements = SPISearchFilterSuggestions.suggestions.map((suggestion) => {
        const linkElement = document.createElement('a')
        linkElement.textContent = suggestion.text
        linkElement.title = suggestion.description
        linkElement.dataset.filter = suggestion.filter
        linkElement.addEventListener('click', (event) => {
          event.preventDefault()

          // Grab the filter and parse it out to get the lengths of each side.
          const separator = ':'
          const filter = linkElement.dataset.filter
          const filterElements = filter.split(separator)
          const valueLength = filterElements.pop().length
          const fieldLength = filterElements.pop().length
          const whitespace = ' ' // To separate the suggested filter from the existing search term

          // Append the filter to the existing search term.
          var currentSearch = searchFieldElement.value.trimEnd()
          searchFieldElement.value = currentSearch + whitespace + filter

          // Finally, focus the value portion of the suggested filter.
          const selectionStart = currentSearch.length + fieldLength + separator.length + whitespace.length
          const selectionEnd = selectionStart + valueLength
          searchFieldElement.focus() // Focus must be set before the selection otherwise the text field does not scroll to end.
          searchFieldElement.setSelectionRange(selectionStart, selectionEnd, 'forward')
        })
        return linkElement
      })

      // Construct the sentence containing all suggestions.
      const lastSuggestionElement = suggestionElements.pop()
      filterSuggestionsElement.insertAdjacentText('beforeend', 'Try filtering by ')
      suggestionElements.forEach((suggestionElement) => {
        filterSuggestionsElement.insertAdjacentElement('beforeend', suggestionElement)
        filterSuggestionsElement.insertAdjacentText('beforeend', ', ')
      })
      filterSuggestionsElement.insertAdjacentText('beforeend', 'or ')
      filterSuggestionsElement.insertAdjacentElement('beforeend', lastSuggestionElement)
      filterSuggestionsElement.insertAdjacentText('beforeend', '.')
    })
  }

  static formattedFilterDate() {
    var thirtyDaysAgo = new Date()
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

    const year = thirtyDaysAgo.getFullYear()
    const month = thirtyDaysAgo.getMonth() + 1 // Yes, JavaScript returns months as zero based.
    const day = thirtyDaysAgo.getDate() // ... but not the day of the month. That's one based.

    return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  }
}
