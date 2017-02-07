import React, { Component, PropTypes } from 'react';

import sematable, { Table } from 'sematable';

import './App.css';

const columns = [
  {
    key: 'id',
    header: 'ID',
    sortable: true,
    searchable: true,
    primaryKey: true
  },
  { key: 'name', header: 'Application', sortable: true, searchable: true }
];

class MovieTable extends Component {
  render() {
    return <Table {...this.props} columns={columns} />;
  }
}
MovieTable.propTypes = { data: PropTypes.array.isRequired };

const MovieTableContainer = sematable('movies', MovieTable, columns, {
  showPageSize: false,
  showFilter: false
});

const App = () => {
  return (
    <MovieTableContainer
      data={[ { id: 1, name: 'J\xF3i' }, { id: 2, name: 'Andr\xE9s 2' } ]}
    />
  );
};
export default App;
