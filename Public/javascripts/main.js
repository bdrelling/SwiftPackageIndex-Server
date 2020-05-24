// Constants for session key storage.
const SessionKey = {
  searchResults: 'com.swiftpackageindex.searchResults',
}

document.addEventListener('DOMContentLoaded', function(event) {
  // Force external links to open with a _blank target.
  document.addEventListener('click', function(event) {
    var target = event.target
    do {
      if (target.nodeName.toLowerCase() == 'a' && target.hostname != window.location.hostname) {
        target.setAttribute('target', '_blank')
      }
    } while (target = target.parentElement)
  })

  // If there is a search element, configure the search callbacks.
  const queryFieldElement = document.getElementById('query')
  if (!!queryFieldElement) {
    // When user input is entered into the query field, perform the search.
    queryFieldElement.addEventListener('input', _.debounce(function(event) {
      const queryFieldElement = event.target
      const searchQuery = queryFieldElement.value.trim()
      if (searchQuery.length > 0) {
        performSearch(searchQuery)
      } else {
        // With no query, there will be no results.
        setElementHiddenById('results', true)
      }
    }), 200)

    queryFieldElement.addEventListener('keydown', function(event) {
      // The query field should *never* respond to the enter key.
      if (event.keyCode == 13) { event.preventDefault() }

      const resultsElement = document.getElementById('results')
      if (!resultsElement) { return }
      const resultsListElement = resultsElement.querySelector('ul')
      if (!resultsListElement) { return }

      const queryFieldElement = event.target
      if (queryFieldElement.value.length <= 0) { return }

      const searchResults = sessionStorage.getDeserializedItem(SessionKey.searchResults)

      switch (event.keyCode) {
        case 13:
          const selectedItemElement = resultsListElement.children[window.searchResultSelectedIndex]
          const linkElement = selectedItemElement.querySelector('a')
          linkElement.click()
          break
        case 38: // Up arrow
        if (typeof(window.searchResultSelectedIndex) !== 'number') {
            window.searchResultSelectedIndex = searchResults.results.length - 1
          } else {
            window.searchResultSelectedIndex = Math.max(window.searchResultSelectedIndex - 1, 0)
          }
          break
        case 40: // Down arrow
          if (typeof(window.searchResultSelectedIndex) !== 'number') {
            window.searchResultSelectedIndex = 0
          } else {
            window.searchResultSelectedIndex = Math.min(window.searchResultSelectedIndex + 1, searchResults.results.length - 1)
          }
          break
      }

      Array.from(resultsListElement.children).forEach(function(listItemElement, index) {
        if (index == window.searchResultSelectedIndex) {
          listItemElement.classList.add('selected')
          if (window.searchResultSelectedIndex == searchResults.results.length - 1) {
            // Scroll all the way to the bottom, just in case the "More results are available" text is showing.
            resultsElement.scrollTop = resultsElement.scrollHeight
          } else {
            // Ensure that the element is visible, but don't center it in the div. Just move the minimum amount necessary.
            listItemElement.scrollIntoViewIfNeeded(false)
          }
        } else { listItemElement.classList.remove('selected') }
      })
    })
  }
})

window.addEventListener('pageshow', function(event) {
  // If there is a search element, configure the search callbacks.
  const queryFieldElement = document.getElementById('query')
  if (!!queryFieldElement) {
    // If there's already a query in the input field, display results from session storage.
    const searchQuery = queryFieldElement.value.trim()
    if (searchQuery.length > 0) {
      const searchResults = sessionStorage.getDeserializedItem(SessionKey.searchResults)
      if (!!searchResults) {
        clearSearchResults()
        displaySearchResults(searchResults)
      }
    } else {
      // Otherwise, just force the results element to be hidden.
      setElementHiddenById('results', true)
    }
  }
})

function performSearch(searchQuery) {
  const searchUrl = '/api/search?query=' + searchQuery

  // Clear out any existing content. Errors, the loading indicator, or previous results.
  clearSearchResults()

  axios.get(searchUrl).then(function(response) {
    // Cache the search results into session storage, then show them.
    sessionStorage.setSerializedItem(SessionKey.searchResults, response.data)
    displaySearchResults(response.data)

    // Reset the keyboard navigation selected index as these are new results.
    window.searchResultSelectedIndex = null
  }).catch(function(error) {
    console.error(error) // At the very least, always log to the console.
    displayErrorMessage(error)
  })

  // Doesn't matter if there was an error, or valid results, always show the results area.
  setElementHiddenById('results', false)
}

 function clearSearchResults() {
  const resultsElement = document.getElementById('results')
  if (!resultsElement) { return }

  while (resultsElement.lastElementChild) {
    resultsElement.removeChild(resultsElement.lastElementChild)
  }
}

 function displaySearchResults(searchResults) {
  const resultsElement = document.getElementById('results')
  if (!resultsElement) { return }

  // Are there any results?
  const numResults = searchResults.results.length
  if (numResults <= 0) {
    const noResultsElement = document.createElement('p')
    noResultsElement.textContent = 'No Results. Try another search?'
    noResultsElement.classList.add('no_results')
    resultsElement.appendChild(noResultsElement)
  } else {
    // Create an unordered list with the results.
    const resultsListElement = document.createElement('ul')
    searchResults.results.forEach((result, index) => {
      createSearchResultListItemElement(result, resultsListElement)
    })
    resultsElement.appendChild(resultsListElement)

    // Are there more search results available?
    if (searchResults.hasMoreResults) {
      const moreResultsElement = document.createElement('p')
      moreResultsElement.textContent = `More than ${numResults} results match this query. Try a more specific search.`
      moreResultsElement.classList.add('more_results')
      resultsElement.appendChild(moreResultsElement)
    }
  }
}

function displayErrorMessage(error) {
  const resultsElement = document.getElementById('results')
  if (!resultsElement) { return }

  // Container for the error message.
  const errorContainerElement = document.createElement('div')
  errorContainerElement.classList.add('error')
  resultsElement.appendChild(errorContainerElement)

  // Start with an icon.
  const errorIconElement = document.createElement('i')
  errorIconElement.classList.add('icon')
  errorIconElement.classList.add('warning')
  errorContainerElement.appendChild(errorIconElement)

  // Header, with a quick apology.
  const errorHeaderElement = document.createElement('h4')
  errorHeaderElement.textContent = 'Something went wrong. Sorry!'
  errorContainerElement.appendChild(errorHeaderElement)

  // Then, what actually happened.
  const errorMessageElement = document.createElement('p')
  errorContainerElement.appendChild(errorMessageElement)

  // Finally, what was the error?
  if (!!error.response) {
    errorMessageElement.textContent = error.response.status + ' – ' + error.response.statusText

    // Is there any extra information in the "reason" that might be useful?
    if (!!error.response.data && !!error.response.data.reason && error.response.data.reason != error.response.statusText) {
      errorMessageElement.textContent +=  ' – ' + error.response.data.reason
    }
  } else {
    errorMessageElement.textContent = 'Unexpected Error.'
  }
}

// Helpers

function setElementHiddenById(id, hidden) {
  const element = document.getElementById(id)
  if (!!element) { element.hidden = hidden }
}

function createSearchResultListItemElement(result, containerElement) {
  const resultListItemElement = document.createElement('li')

  // A link surrounds the whole content of the list item.
  const linkElement = document.createElement('a')
  linkElement.href = '/packages/' + result.id
  resultListItemElement.appendChild(linkElement)

  // Name and repository identifier need to be grouped to be split.
  const nameAndRepositoryContainer = document.createElement('div')
  linkElement.appendChild(nameAndRepositoryContainer)

  // Name.
  const nameElement = document.createElement('h4')
  nameElement.textContent = result.name
  nameAndRepositoryContainer.appendChild(nameElement)

  // Repository identifier.
  const repositoryElement = document.createElement('small')
  repositoryElement.textContent = result.owner + '/' + result.package_name
  nameAndRepositoryContainer.appendChild(repositoryElement)

  // Summary.
  const summaryElement = document.createElement('p')
  summaryElement.textContent = result.summary
  linkElement.appendChild(summaryElement)

  containerElement.appendChild(resultListItemElement)
}

// Custom session storage serialisation helpers

Storage.prototype.getDeserializedItem = function(key) {
  const value = this.getItem(key)
  return (!!value) ? JSON.parse(value) : null
}

Storage.prototype.setSerializedItem = function (key, value) {
  this.setItem(key, JSON.stringify(value))
}
