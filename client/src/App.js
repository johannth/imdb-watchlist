import React, { Component, PropTypes } from 'react';
import { connect } from 'react-redux';
import sematable, { Table } from 'sematable';

import './App.css';

const RuntimeCell = ({ row }) => {
  return <span>{row.runTime ? row.runTime : '?'}</span>;
};
RuntimeCell.propTypes = { row: PropTypes.object.isRequired };

const TitleCell = ({ row }) => {
  return <a target="_blank" href={row.href}>{row.title}</a>;
};

const columns = [
  { key: 'id', header: 'ID', primaryKey: true, hidden: true },
  {
    key: 'title',
    header: 'Title',
    sortable: true,
    searchable: true,
    Component: TitleCell
  },
  { key: 'runTime', header: 'Run Time (min)', sortable: true },
  { key: 'metascore', header: 'Metascore', sortable: true },
  { key: 'imdbRating', header: 'IMDB Rating', sortable: true },
  { key: 'priority', header: 'Priority', sortable: true }
];

class MovieTable extends Component {
  render() {
    return <Table {...this.props} columns={columns} />;
  }
}
MovieTable.propTypes = { data: PropTypes.array.isRequired };

const MovieTableContainer = sematable('movies', MovieTable, columns, {
  showPageSize: false,
  showFilter: false,
  defaultPageSize: 500,
  sortKey: 'priority',
  sortDirection: 'desc'
});

const mapStateToProps = state => {
  return { list: state.data.list };
};

const AppPage = ({ list }) => {
  return (
    <div>
      <h1>Watchlist</h1>
      {list ? <MovieTableContainer data={list} /> : <div>Loading...</div>}
    </div>
  );
};

const App = connect(mapStateToProps)(AppPage);
export default App;
